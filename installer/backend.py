#!/usr/bin/env python3
"""Бекенд установника BlackVarmir Arch.

Викликається з інтерфейсу (Installer.qml) і повертає JSON у stdout:

    backend.py disks                  диски, розділи, вільне місце, знайдена Windows
    backend.py plan < вибір.json      що саме зміниться на диску (без змін; лише план)
    backend.py run  < вибір.json      виконує встановлення (з "dryRun": true лише показує кроки)

`disks` і `plan` нічого не пишуть на диск. `run` пише, тому вимагає root і "confirm": true.
Хід виконання: по рядку JSON у stdout ({"type": "steps|step|log|error|done", ...}).

Змінні оточення:
    BV_FAKE_DISKS=файл.json   замість lsblk читати JSON з файлу (для перевірки інтерфейсу без дисків)
"""

import json
import os
import re
import shlex
import subprocess
import sys
import time

MIB = 1 << 20
GIB = 1 << 30

# Типи розділів GPT
TYPE_EFI = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
TYPE_MS_BASIC = "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"
TYPE_MS_RESERVED = "e3c9e316-0b5c-4db8-817d-f92df00215ae"
TYPE_MS_RECOVERY = "de94bba4-06d1-4d40-a16a-bfd50179d6ac"
TYPE_LINUX = "0fc63daf-8483-4772-8e79-3d69d8477de4"

MIN_LINUX = 40 * GIB          # менше під систему не даємо
ESP_SIZE = 1 * GIB            # новий EFI-розділ (коли стираємо диск)
ALIGN = MIB
TAIL = 2 * MIB                # запас наприкінці диска під резервну GPT
NTFS_MARGIN = 2 * GIB         # запас над мінімальним розміром NTFS при стисканні

# Підтоми Btrfs: корінь, домашня тека, знімки (snapper)
SUBVOLUMES = [("@", "/"), ("@home", "/home"), ("@snapshots", "/.snapshots")]
BTRFS_OPTS = "noatime,compress=zstd:1,space_cache=v2"


class PlanError(Exception):
    """Вибір неможливий або небезпечний: показується користувачу, на диск нічого не пишеться."""


# ───────────────────────── Диски ─────────────────────────

LSBLK_COLS = ("NAME,SIZE,TYPE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,LABEL,MOUNTPOINTS,"
              "MODEL,PKNAME,RM,RO,PTTYPE,PARTN,START,LOG-SEC")


def run_lsblk():
    fake = os.environ.get("BV_FAKE_DISKS")
    if fake:
        with open(fake, encoding="utf-8") as f:
            return json.load(f)
    out = subprocess.run(["lsblk", "-J", "-b", "-p", "-o", LSBLK_COLS],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def to_int(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def to_bool(v):
    return v is True or str(v).lower() in ("1", "true")


def mounts_of(node):
    m = node.get("mountpoints")
    if m is None and node.get("mountpoint"):
        m = [node["mountpoint"]]
    return [x for x in (m or []) if x]


def live_medium_disks():
    """Диск, з якого завантажено живий образ: його не можна обирати."""
    if os.environ.get("BV_FAKE_DISKS"):
        return set()
    out = set()
    for mp in ("/run/archiso/bootmnt", "/run/archiso/copytoram"):
        try:
            src = subprocess.run(["findmnt", "-no", "SOURCE", mp],
                                 capture_output=True, text=True).stdout.strip()
            if src:
                out.add(src)
        except OSError:
            pass
    return out


def free_gaps(parts, disk_size, sector):
    """Вільні проміжки між розділами (у байтах), вирівняні до 1 МіБ."""
    used = sorted((p["start"], p["start"] + p["size"]) for p in parts)
    gaps, cursor = [], ALIGN
    end_limit = disk_size - TAIL
    for s, e in used:
        if s - cursor >= 16 * MIB:
            gaps.append({"start": cursor, "size": (s - cursor) // ALIGN * ALIGN})
        cursor = max(cursor, (e + ALIGN - 1) // ALIGN * ALIGN)
    if end_limit - cursor >= 16 * MIB:
        gaps.append({"start": cursor, "size": (end_limit - cursor) // ALIGN * ALIGN})
    return gaps


def ntfs_min_size(path):
    """Мінімальний розмір NTFS у байтах (потрібен root); None, якщо дізнатися не вдалося."""
    if os.geteuid() != 0 or os.environ.get("BV_FAKE_DISKS"):
        return None
    r = subprocess.run(["ntfsresize", "--info", "--force", "--no-progress-bar", path],
                       capture_output=True, text=True)
    text = r.stdout + r.stderr
    if "hibernat" in text.lower():
        return -1  # Windows у режимі сну (швидкий запуск): стискати не можна
    for line in text.splitlines():
        if "You might resize at" in line:
            return to_int(line.split("at")[1].split("bytes")[0].strip())
    return None


def parse_disks(data):
    live = live_medium_disks()
    disks = []
    for dev in data.get("blockdevices", []):
        if dev.get("type") != "disk":
            continue
        # Не диски для встановлення: zram, loop, оптичні, порожні пристрої
        if to_int(dev.get("size")) < GIB or dev["name"].startswith(("/dev/zram", "/dev/loop", "/dev/sr")):
            continue
        sector = to_int(dev.get("log-sec"), 512) or 512
        size = to_int(dev.get("size"))
        parts = []
        for c in dev.get("children") or []:
            if c.get("type") not in ("part",):
                continue
            parts.append({
                "path": c["name"],
                "number": to_int(c.get("partn")),
                "start": to_int(c.get("start")) * sector,
                "size": to_int(c.get("size")),
                "fstype": c.get("fstype") or "",
                "label": c.get("label") or "",
                "partlabel": c.get("partlabel") or "",
                "parttype": (c.get("parttype") or "").lower(),
                "partuuid": c.get("partuuid") or "",
                "mounts": mounts_of(c),
            })
        efi = next((p for p in parts if p["parttype"] == TYPE_EFI), None)
        windows = []
        for p in parts:
            # NTFS-розділ із типом «Microsoft basic data» на диску з EFI-розділом
            if p["fstype"] in ("ntfs", "BitLocker") and p["parttype"] == TYPE_MS_BASIC and efi:
                # Менші NTFS (відновлення, OEM) і розділ під 1 ГіБ не вважаємо системним
                if p["size"] >= 20 * GIB or p["fstype"] == "BitLocker":
                    windows.append(p["path"])
        disk_mounts = mounts_of(dev) + [m for p in parts for m in p["mounts"]]
        path = dev["name"]
        d = {
            "path": path,
            "model": (dev.get("model") or "").strip(),
            "size": size,
            "removable": to_bool(dev.get("rm")),
            "ptable": dev.get("pttype") or "",
            "sector": sector,
            "partitions": parts,
            "free": free_gaps(parts, size, sector),
            "efi": efi["path"] if efi else "",
            "windows": [],
            "busy": bool(disk_mounts) or path in live,
            "live": path in live,
            "mounts": disk_mounts,
        }
        for w in windows:
            p = next(x for x in parts if x["path"] == w)
            info = {"path": w, "size": p["size"], "bitlocker": p["fstype"] == "BitLocker",
                    "minBytes": None, "hibernated": False}
            if not info["bitlocker"]:
                m = ntfs_min_size(w)
                if m == -1:
                    info["hibernated"] = True
                else:
                    info["minBytes"] = m
            d["windows"].append(info)
        disks.append(d)
    return disks


def cmd_disks():
    return {"disks": parse_disks(run_lsblk())}


# ───────────────────────── План ─────────────────────────

def find_disk(disks, path):
    d = next((x for x in disks if x["path"] == path), None)
    if not d:
        raise PlanError("Disk not found: %s" % path)
    if d["live"]:
        raise PlanError("This is the disk the installer was started from.")
    if d["busy"]:
        raise PlanError("The disk is in use (mounted): %s" % ", ".join(d["mounts"]))
    return d


def part_path(disk, number):
    """Шлях розділу за номером: /dev/sda3, але /dev/nvme0n1p3 і /dev/mmcblk0p3."""
    base = disk["path"]
    return base + ("p" if base[-1].isdigit() else "") + str(number)


def fmt_size(n):
    return "%.0f GB" % (n / GIB) if n >= GIB else "%.0f MB" % (n / MIB)


def btrfs_steps(root, esp, esp_format):
    """Файлові системи, підтоми й монтування в /mnt. Однакові для всіх режимів."""
    steps = []
    if esp_format:
        steps.append({"id": "mkfs-esp", "title": "Format the EFI partition",
                      "cmds": [["mkfs.fat", "-F32", "-n", "EFI", esp]]})
    steps.append({"id": "mkfs-root", "title": "Create the Btrfs file system",
                  "cmds": [["mkfs.btrfs", "-f", "-L", "BlackVarmir", root]]})
    cmds = [["mount", root, "/mnt"]]
    cmds += [["btrfs", "subvolume", "create", "/mnt/" + name] for name, _ in SUBVOLUMES]
    cmds += [["umount", "/mnt"],
             ["mount", "-o", BTRFS_OPTS + ",subvol=@", root, "/mnt"],
             ["mkdir", "-p", "/mnt/home", "/mnt/.snapshots", "/mnt/boot/efi"],
             ["mount", "-o", BTRFS_OPTS + ",subvol=@home", root, "/mnt/home"],
             ["mount", "-o", BTRFS_OPTS + ",subvol=@snapshots", root, "/mnt/.snapshots"],
             ["mount", esp, "/mnt/boot/efi"]]
    steps.append({"id": "subvolumes", "title": "Create subvolumes @, @home, @snapshots and mount", "cmds": cmds})
    return steps


def plan_erase(disks, ch):
    d = find_disk(disks, ch["disk"])
    if d["size"] < MIN_LINUX + ESP_SIZE:
        raise PlanError("The disk is too small (needs at least %s)." % fmt_size(MIN_LINUX + ESP_SIZE))
    esp, root = part_path(d, 1), part_path(d, 2)
    steps = [{"id": "partition", "title": "Erase the disk and create partitions",
              "cmds": [["sgdisk", "--zap-all", d["path"]],
                       ["sgdisk", "-n", "1:0:+%dM" % (ESP_SIZE // MIB), "-t", "1:ef00", "-c", "1:EFI", d["path"]],
                       ["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:BlackVarmir", d["path"]],
                       ["partprobe", d["path"]], ["udevadm", "settle"]]}]
    steps += btrfs_steps(root, esp, esp_format=True)
    summary = [{"kind": "erased", "text": "%s (%s %s): everything is erased" % (d["path"], d["model"] or "disk", fmt_size(d["size"]))},
               {"kind": "created", "text": "EFI, %s" % fmt_size(ESP_SIZE)},
               {"kind": "created", "text": "Arch, Btrfs, %s" % fmt_size(d["size"] - ESP_SIZE)}]
    return steps, summary, d


def plan_alongside(disks, ch):
    d = find_disk(disks, ch["disk"])
    win = next((w for w in d["windows"] if w["path"] == ch.get("windowsPart")), None)
    if not win:
        raise PlanError("Windows partition not found on this disk.")
    if win["bitlocker"]:
        raise PlanError("The Windows partition is encrypted with BitLocker. Shrink it in Windows first.")
    if win["hibernated"]:
        raise PlanError("Windows is hibernated (Fast Startup). Shut it down completely and try again.")
    if not d["efi"]:
        raise PlanError("No EFI partition found on this disk.")
    if win["minBytes"] is None:
        raise PlanError("Cannot measure the Windows partition. Run the installer as root.")
    linux = to_int(ch.get("linuxBytes")) // ALIGN * ALIGN
    if linux < MIN_LINUX:
        raise PlanError("Arch needs at least %s." % fmt_size(MIN_LINUX))
    wp = next(p for p in d["partitions"] if p["path"] == win["path"])
    new_win = win["size"] - linux
    if new_win < win["minBytes"] + NTFS_MARGIN:
        raise PlanError("Windows needs at least %s. Give Arch less." % fmt_size(win["minBytes"] + NTFS_MARGIN))
    # Розділ Windows має бути останнім перед вільним місцем, інакше нове місце не буде суцільним
    nxt = [p for p in d["partitions"] if p["start"] > wp["start"]]
    if nxt and min(p["start"] for p in nxt) < wp["start"] + wp["size"] + linux:
        raise PlanError("There is another partition right after Windows. Use custom partitioning.")
    n = wp["number"]
    new_end_mib = (wp["start"] + new_win) // MIB
    linux_start_mib = new_end_mib
    efi = d["efi"]
    free_numbers = {p["number"] for p in d["partitions"]}
    new_n = max(free_numbers) + 1
    root = part_path(d, new_n)
    steps = [
        {"id": "shrink-fs", "title": "Shrink the Windows file system",
         "cmds": [["ntfsresize", "--force", "--no-progress-bar", "--size", str(new_win - 8 * MIB), win["path"]]]},
        {"id": "shrink-part", "title": "Shrink the Windows partition",
         "cmds": [["sgdisk", "-d", str(n), d["path"]],
                  ["sgdisk", "-n", "%d:%dM:%dM" % (n, wp["start"] // MIB, new_end_mib - 1),
                   "-t", "%d:0700" % n, "-c", "%d:%s" % (n, wp["partlabel"] or "Basic data partition"),
                   "-u", "%d:%s" % (n, wp["partuuid"] or "R"), d["path"]],
                  ["sgdisk", "-n", "%d:%dM:0" % (new_n, linux_start_mib), "-t", "%d:8300" % new_n,
                   "-c", "%d:BlackVarmir" % new_n, d["path"]],
                  ["partprobe", d["path"]], ["udevadm", "settle"]]},
    ]
    steps += btrfs_steps(root, efi, esp_format=False)
    summary = [
        {"kind": "unchanged", "text": "EFI (%s): shared, not formatted" % efi},
        {"kind": "shrunk", "text": "%s: %s → %s (Windows data is kept)" % (win["path"], fmt_size(win["size"]), fmt_size(new_win))},
        {"kind": "created", "text": "Arch, Btrfs, %s" % fmt_size(linux)},
        {"kind": "added", "text": "Windows entry in the GRUB menu"},
    ]
    for p in d["partitions"]:
        if p["path"] not in (efi, win["path"]):
            summary.insert(1, {"kind": "unchanged", "text": "%s (%s)" % (p["path"], p["fstype"] or "other")})
    return steps, summary, d


ROLES = ("/", "/home", "efi", "windows", "keep")


def plan_custom(disks, ch):
    """Власна розмітка: користувач призначає ролі наявним розділам і вільним ділянкам.

    ch["custom"] = [{"part": "/dev/sda5"|None, "free": {"start": B, "size": B}|None,
                     "role": "/" | "/home" | "efi" | "keep", "format": bool}]
    Розділи без запису не чіпаємо.
    """
    d = find_disk(disks, ch["disk"])
    items = ch.get("custom") or []
    roles = [i.get("role") for i in items]
    for i in items:
        if i.get("role") not in ROLES:
            raise PlanError("Unknown role: %s" % i.get("role"))
    if roles.count("/") != 1:
        raise PlanError("Choose exactly one partition for / (the system).")
    if roles.count("efi") != 1:
        raise PlanError("Choose exactly one EFI partition.")
    if roles.count("/home") > 1:
        raise PlanError("Only one /home is supported.")
    known = {p["path"]: p for p in d["partitions"]}
    steps, summary, mounts = [], [], {}
    next_n = max([p["number"] for p in d["partitions"]] + [0]) + 1
    create = []
    for i in items:
        if i.get("free"):
            f = i["free"]
            if not any(g["start"] <= f["start"] and f["start"] + f["size"] <= g["start"] + g["size"] for g in d["free"]):
                raise PlanError("Selected free space does not exist.")
            path = part_path(d, next_n)
            create.append((next_n, f, i["role"]))
            i = dict(i, part=path, format=True)
            next_n += 1
        elif i.get("part") not in known:
            raise PlanError("Partition not found: %s" % i.get("part"))
        if i["role"] != "keep":
            mounts[i["role"]] = i
    for n, f, role in create:
        end = f["start"] + f["size"]
        code = "ef00" if role == "efi" else "8300"
        steps_cmd = ["sgdisk", "-n", "%d:%dM:%dM" % (n, f["start"] // MIB, end // MIB - 1), "-t", "%d:%s" % (n, code), d["path"]]
        steps.append({"id": "create-%d" % n, "title": "Create partition %d" % n, "cmds": [steps_cmd, ["partprobe", d["path"]], ["udevadm", "settle"]]})
    root = mounts["/"]["part"]
    esp = mounts["efi"]["part"]
    rp = known.get(root)
    if rp and rp["size"] < MIN_LINUX and not mounts["/"].get("free"):
        raise PlanError("The system partition needs at least %s." % fmt_size(MIN_LINUX))
    esp_format = bool(mounts["efi"].get("format"))
    steps += btrfs_steps(root, esp, esp_format)
    if "/home" in mounts:
        home = mounts["/home"]
        # Власна /home зберігається, якщо format=false: монтуємо поверх підтому @home не створюючи
        steps[-1]["cmds"] = [c for c in steps[-1]["cmds"] if not (len(c) > 3 and c[-1] == "/mnt/home" and "subvol=@home" in c[-2])]
        if home.get("format"):
            steps.insert(-1, {"id": "mkfs-home", "title": "Format /home", "cmds": [["mkfs.ext4", "-F", "-L", "home", home["part"]]]})
        steps[-1]["cmds"].append(["mount", home["part"], "/mnt/home"])
        summary.append({"kind": "created" if home.get("format") else "unchanged", "text": "/home → %s%s" % (home["part"], "" if home.get("format") else " (kept)")})
    summary.insert(0, {"kind": "unchanged" if not esp_format else "created", "text": "EFI: %s%s" % (esp, " (formatted)" if esp_format else " (kept)")})
    summary.insert(1, {"kind": "created", "text": "/ → %s (Btrfs, formatted)" % root})
    summary.append({"kind": "unchanged", "text": "Other partitions are not touched"})
    return steps, summary, d


def cmd_plan(ch):
    disks = parse_disks(run_lsblk())
    mode = ch.get("mode")
    try:
        fn = {"erase": plan_erase, "alongside": plan_alongside, "custom": plan_custom}[mode]
    except KeyError:
        return {"ok": False, "error": "Unknown mode: %s" % mode}
    try:
        steps, summary, d = fn(disks, ch)
    except PlanError as e:
        return {"ok": False, "error": str(e)}
    # GRUB і os-prober: Windows додається в меню, якщо він є
    summary.append({"kind": "info", "text": "Bootloader: GRUB (UEFI), snapshots in the boot menu"})
    return {"ok": True, "disk": d["path"], "steps": steps, "summary": summary}


# ───────────────────────── Виконання ─────────────────────────

MNT = "/mnt"
LOCALREPO = "/opt/blackvarmir-localrepo"
REPO_SRC = os.environ.get("BV_REPO") or "/opt/blackvarmir-dots"
# Мінімум для завантаження: решту (Hyprland, оболонка, програми) ставить install.sh з репозиторію
BASE_PKGS = ["base", "base-devel", "linux-lts", "linux-firmware", "intel-ucode", "amd-ucode",
             "btrfs-progs", "dosfstools", "grub", "efibootmgr", "os-prober", "networkmanager",
             "sudo", "git", "fish", "rsync", "paru-bin", "ttf-geist", "bibata-cursor-theme-bin"]
USER_RE = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")
HOST_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{0,62}$")


def emit(**kw):
    print(json.dumps(kw, ensure_ascii=False), flush=True)


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][A-Z0-9]|\x1b[=>]")
LOG_FILES = ["/var/log/blackvarmir-install.log", "/tmp/blackvarmir-install.log"]
_logfile = None


def log_to_file(line):
    """Повний журнал установки (на живій системі і потім у новій: /var/log/blackvarmir-install.log)."""
    global _logfile
    if _logfile is None:
        _logfile = False
        for path in LOG_FILES:
            try:
                _logfile = open(path, "a", encoding="utf-8", buffering=1)
                break
            except OSError:
                continue
    if _logfile:
        _logfile.write(line + "\n")


_last_emit = 0.0


def emit_log(line, force=False):
    """Рядок у журнал; в інтерфейс не частіше 5 разів на секунду (pacman малює прогрес сотнями рядків)."""
    global _last_emit
    log_to_file(line)
    now = time.monotonic()
    if force or now - _last_emit >= 0.2:
        _last_emit = now
        emit(type="log", line=line)


class Runner:
    """Виконує команди, передаючи вивід інтерфейсу. У dry-run лише показує, що було б виконано."""

    def __init__(self, dry):
        self.dry = dry

    def run(self, cmd, stdin=None, secret=False, check=True):
        emit_log("$ " + " ".join(shlex.quote(c) for c in cmd) + (" < (stdin)" if secret else ""), force=True)
        if self.dry:
            return 0
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE if stdin is not None else subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=False)
        if stdin is not None:
            p.stdin.write(stdin.encode())
            p.stdin.close()
        # pacman і curl малюють прогрес через \r без нового рядка: ділимо і по \r, і по \n
        fd, buf = p.stdout.fileno(), b""
        while True:
            chunk = os.read(fd, 4096)
            if not chunk:
                break
            buf += chunk
            *parts, buf = re.split(rb"[\r\n]+", buf)
            for part in parts:
                text = ANSI_RE.sub("", part.decode("utf-8", "replace")).strip()
                if text:
                    emit_log(text)
        tail = ANSI_RE.sub("", buf.decode("utf-8", "replace")).strip()
        if tail:
            emit_log(tail, force=True)
        rc = p.wait()
        if check and rc != 0:
            raise RuntimeError("%s exited with %d" % (cmd[0], rc))
        return rc

    def chroot(self, cmd, **kw):
        return self.run(["arch-chroot", MNT] + cmd, **kw)

    def write(self, path, content, mode=0o644):
        emit(type="log", line="write %s" % path)
        if self.dry:
            return
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        os.chmod(path, mode)


def pacman_conf_for_pacstrap():
    """pacman.conf живого образу, але з локальним репозиторієм на місці, де він лежить на ISO."""
    with open("/etc/pacman.conf", encoding="utf-8") as f:
        text = f.read()
    text = re.split(r"^\[blackvarmir-local\]", text, flags=re.M)[0].rstrip() + "\n"
    if os.path.isdir(LOCALREPO):
        text += "\n[blackvarmir-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n" % LOCALREPO
    return text


def validate_user(u):
    name, host = u.get("name", ""), u.get("hostname", "")
    full = u.get("fullName", "") or name
    if not USER_RE.match(name):
        raise PlanError("Invalid user name.")
    if not HOST_RE.match(host):
        raise PlanError("Invalid computer name.")
    if ":" in full or "\n" in full:
        raise PlanError("Invalid full name.")
    if not u.get("password"):
        raise PlanError("Password is empty.")
    return name, full, host


def settings_json(ch, user):
    """Початкові налаштування оболонки нового користувача: те, що обрано в установнику."""
    wp = ch.get("wallpaper") or ""
    d = {"shellLang": ch.get("lang") or "en", "kbLayouts": ch.get("layouts") or ["us"]}
    if wp:
        d["wallpaper"] = "/home/%s/.local/share/blackvarmir/wallpapers/%s" % (user, os.path.basename(wp))
    return json.dumps(d, indent=2, ensure_ascii=False) + "\n"


def extra_steps(r, ch, disk):
    name, full, host = validate_user(ch["user"])
    lang = ch.get("lang") if ch.get("lang") in ("en", "uk") else "en"
    layouts = ch.get("layouts") or ["us"]
    keymap = re.sub(r"[^a-z0-9_-]", "", str(layouts[0]).split(":")[0].lower()) or "us"
    removable = ch.get("mode") == "erase"  # власний EFI-розділ: запасний шлях запуску безпечний
    home = "%s/home/%s" % (MNT, name)

    def base():
        r.write("/tmp/bv-pacman.conf", "" if r.dry else pacman_conf_for_pacstrap())
        r.run(["pacstrap", "-K", "-C", "/tmp/bv-pacman.conf", MNT] + BASE_PKGS)

    def fstab():
        emit(type="log", line="$ genfstab -U %s >> %s/etc/fstab" % (MNT, MNT))
        if not r.dry:
            out = subprocess.run(["genfstab", "-U", MNT], check=True, capture_output=True, text=True).stdout
            with open(MNT + "/etc/fstab", "a", encoding="utf-8") as f:
                f.write(out)

    def system():
        script = os.path.join(REPO_SRC, "installer", "chroot-setup.sh")
        r.run(["install", "-Dm755", script, MNT + "/root/bv-chroot-setup.sh"])
        r.chroot(["/root/bv-chroot-setup.sh", name, full, host, lang, keymap])
        r.chroot(["chpasswd"], stdin="%s:%s\n" % (name, ch["user"]["password"]), secret=True)
        # Wi-Fi, до якого підключились під час установки, лишається і в новій системі
        r.run(["bash", "-c", "mkdir -p {m}/etc/NetworkManager/system-connections && "
               "cp -a /etc/NetworkManager/system-connections/. {m}/etc/NetworkManager/system-connections/ 2>/dev/null; "
               "chmod 600 {m}/etc/NetworkManager/system-connections/* 2>/dev/null; true".format(m=MNT)])

    def bootloader():
        r.run(["sed", "-i", "-E", "s/^#?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/", MNT + "/etc/default/grub"])
        r.run(["bash", "-c", "grep -q '^GRUB_DISABLE_OS_PROBER' %s/etc/default/grub || "
               "echo 'GRUB_DISABLE_OS_PROBER=false' >> %s/etc/default/grub" % (MNT, MNT)])
        r.chroot(["grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi",
                  "--bootloader-id=BlackVarmir", "--recheck"])
        if removable:
            r.chroot(["grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--removable"])
        r.chroot(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"])

    def desktop():
        r.run(["rsync", "-a", "--exclude", "iso/", REPO_SRC.rstrip("/") + "/", home + "/blackvarmir-dots/"])
        r.chroot(["chown", "-R", "%s:%s" % (name, name), "/home/" + name])
        r.write(home + "/.config/blackvarmir/settings.json", settings_json(ch, name))
        r.chroot(["chown", "-R", "%s:%s" % (name, name), "/home/%s/.config" % name])
        r.chroot(["sudo", "-H", "-u", name, "env", "BV_CHROOT=1", "bash",
                  "/home/%s/blackvarmir-dots/install.sh" % name, "--skip-gpu"])
        r.run(["rm", "-f", MNT + "/etc/sudoers.d/99-bv-install"])

    def finish():
        r.run(["rm", "-f", MNT + "/root/bv-chroot-setup.sh"])
        for path in LOG_FILES:
            if os.path.exists(path) and not r.dry:
                r.run(["install", "-Dm644", path, MNT + "/var/log/blackvarmir-install.log"])
                break
        r.run(["sync"])
        r.run(["umount", "-R", MNT])

    return [
        {"id": "base", "title": "Install the base system", "fn": base},
        {"id": "fstab", "title": "Generate fstab", "fn": fstab},
        {"id": "system", "title": "Configure language, user and network", "fn": system},
        {"id": "boot", "title": "Install the GRUB bootloader", "fn": bootloader},
        {"id": "desktop", "title": "Install BlackVarmir (install.sh)", "fn": desktop},
        {"id": "finish", "title": "Finish and unmount", "fn": finish},
    ]


def cmd_run(ch):
    dry = bool(ch.get("dryRun"))
    if not dry and os.geteuid() != 0:
        emit(type="error", message="The installer must run as root."); return 1
    if not dry and not ch.get("confirm"):
        emit(type="error", message="Not confirmed."); return 1
    p = cmd_plan(ch)
    if not p["ok"]:
        emit(type="error", message=p["error"]); return 1
    disks = parse_disks(run_lsblk())  # ще раз: стан диска міг змінитися після підтвердження
    try:
        find_disk(disks, ch["disk"])
        steps = [dict(s) for s in p["steps"]] + extra_steps(Runner(dry), ch, p["disk"])
    except PlanError as e:
        emit(type="error", message=str(e)); return 1
    r = Runner(dry)
    emit(type="steps", titles=[s["title"] for s in steps], dryRun=dry)
    for i, st in enumerate(steps):
        emit(type="step", index=i, state="start")
        try:
            if "fn" in st:
                st["fn"]()
            else:
                for c in st["cmds"]:
                    r.run(c)
            if dry:
                time.sleep(0.4)
        except Exception as e:  # noqa: BLE001 — будь-яка помилка зупиняє встановлення
            emit(type="error", message="%s: %s" % (st["title"], e), index=i)
            if not dry:  # відмонтувати, щоб диск не лишався зайнятим і можна було повторити
                subprocess.run(["umount", "-R", MNT], capture_output=True)
            return 1
        emit(type="step", index=i, state="ok")
    emit(type="done")
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] not in ("disks", "plan", "run"):
        print(__doc__, file=sys.stderr)
        return 2
    if argv[1] == "run":
        return cmd_run(json.load(sys.stdin))
    if argv[1] == "disks":
        out = cmd_disks()
    else:
        out = cmd_plan(json.load(sys.stdin))
    json.dump(out, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
