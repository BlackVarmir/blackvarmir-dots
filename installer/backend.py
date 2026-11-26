#!/usr/bin/env python3
"""Бекенд установника BlackVarmir Arch.

Викликається з інтерфейсу (Installer.qml) і повертає JSON у stdout:

    backend.py disks                  диски, розділи, вільне місце, знайдена Windows
    backend.py plan < вибір.json      що саме зміниться на диску (без змін; лише план)

Нічого не пише на диск. Виконання плану (`run`) додається окремою зміною.

Змінні оточення:
    BV_FAKE_DISKS=файл.json   замість lsblk читати JSON з файлу (для перевірки інтерфейсу без дисків)
"""

import json
import os
import subprocess
import sys

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


def main(argv):
    if len(argv) < 2 or argv[1] not in ("disks", "plan"):
        print(__doc__, file=sys.stderr)
        return 2
    if argv[1] == "disks":
        out = cmd_disks()
    else:
        out = cmd_plan(json.load(sys.stdin))
    json.dump(out, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
