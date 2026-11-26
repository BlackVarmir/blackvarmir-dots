import json, os, sys, tempfile, unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
os.environ["BV_FAKE_DISKS"] = "x"  # перемикає backend на фікстуру, див. load()
import backend  # noqa: E402

GIB = 1 << 30


def part(dev, n, start_mib, size, fstype="", parttype="", label="", mounts=None):
    return {"name": "%s%s%d" % (dev, "p" if dev[-1].isdigit() else "", n), "type": "part", "size": size,
            "fstype": fstype or None, "parttype": parttype, "partlabel": label, "partuuid": "uuid-%d" % n,
            "label": None, "mountpoints": mounts or [None], "partn": n, "start": start_mib * 2048, "log-sec": 512}


def disk(dev, size, children, model="TestDisk"):
    return {"name": dev, "type": "disk", "size": size, "model": model, "rm": False, "pttype": "gpt",
            "mountpoints": [None], "log-sec": 512, "children": children}


def windows_disk(bitlocker=False):
    fs = "BitLocker" if bitlocker else "ntfs"
    return disk("/dev/sda", 512 * GIB, [
        part("/dev/sda", 1, 1, 260 << 20, "vfat", backend.TYPE_EFI),
        part("/dev/sda", 2, 261, 16 << 20, "", backend.TYPE_MS_RESERVED),
        part("/dev/sda", 3, 277, 400 * GIB, fs, backend.TYPE_MS_BASIC),
    ])


def load(devs, min_bytes=100 * GIB, hibernated=False):
    backend.run_lsblk = lambda: {"blockdevices": devs}
    backend.ntfs_min_size = lambda p: -1 if hibernated else min_bytes
    os.environ.pop("BV_FAKE_DISKS", None)


class Disks(unittest.TestCase):
    def test_windows_detected(self):
        load([windows_disk()])
        d = backend.cmd_disks()["disks"][0]
        self.assertEqual(d["efi"], "/dev/sda1")
        self.assertEqual([w["path"] for w in d["windows"]], ["/dev/sda3"])
        self.assertFalse(d["windows"][0]["bitlocker"])

    def test_bitlocker(self):
        load([windows_disk(bitlocker=True)])
        w = backend.cmd_disks()["disks"][0]["windows"][0]
        self.assertTrue(w["bitlocker"])

    def test_mounted_disk_is_busy(self):
        dev = windows_disk()
        dev["children"][2]["mountpoints"] = ["/mnt/win"]
        load([dev])
        self.assertTrue(backend.cmd_disks()["disks"][0]["busy"])

    def test_skips_zram_and_empty(self):
        load([disk("/dev/zram0", 8 * GIB, []), disk("/dev/sdz", 0, []), disk("/dev/vda", 64 * GIB, [])])
        self.assertEqual([d["path"] for d in backend.cmd_disks()["disks"]], ["/dev/vda"])

    def test_nvme_names(self):
        d = {"path": "/dev/nvme0n1"}
        self.assertEqual(backend.part_path(d, 2), "/dev/nvme0n1p2")
        self.assertEqual(backend.part_path({"path": "/dev/sda"}, 2), "/dev/sda2")

    def test_free_space(self):
        load([windows_disk()])
        free = backend.cmd_disks()["disks"][0]["free"]
        self.assertEqual(len(free), 1)
        self.assertGreater(free[0]["size"], 90 * GIB)


class Plans(unittest.TestCase):
    def plan(self, ch):
        return backend.cmd_plan(ch)

    def test_erase_empty_disk(self):
        load([disk("/dev/vda", 64 * GIB, [])])
        r = self.plan({"mode": "erase", "disk": "/dev/vda"})
        self.assertTrue(r["ok"], r)
        cmds = [c for s in r["steps"] for c in s["cmds"]]
        self.assertIn(["sgdisk", "--zap-all", "/dev/vda"], cmds)
        self.assertIn(["mkfs.btrfs", "-f", "-L", "BlackVarmir", "/dev/vda2"], cmds)

    def test_erase_too_small(self):
        load([disk("/dev/vda", 20 * GIB, [])])
        self.assertFalse(self.plan({"mode": "erase", "disk": "/dev/vda"})["ok"])

    def test_refuses_mounted(self):
        dev = disk("/dev/vda", 64 * GIB, [part("/dev/vda", 1, 1, 10 * GIB, "ext4", mounts=["/"])])
        load([dev])
        self.assertFalse(self.plan({"mode": "erase", "disk": "/dev/vda"})["ok"])

    def test_unknown_disk(self):
        load([disk("/dev/vda", 64 * GIB, [])])
        self.assertFalse(self.plan({"mode": "erase", "disk": "/dev/zzz"})["ok"])

    def test_alongside_never_formats_efi(self):
        load([windows_disk()])
        r = self.plan({"mode": "alongside", "disk": "/dev/sda", "windowsPart": "/dev/sda3", "linuxBytes": 100 * GIB})
        self.assertTrue(r["ok"], r)
        cmds = [c for s in r["steps"] for c in s["cmds"]]
        self.assertFalse(any(c[0] == "mkfs.fat" for c in cmds))
        self.assertFalse(any(c[0] == "sgdisk" and "--zap-all" in c for c in cmds))
        self.assertEqual(cmds[0][0], "ntfsresize")
        self.assertIn(["mkfs.btrfs", "-f", "-L", "BlackVarmir", "/dev/sda4"], cmds)

    def test_alongside_bitlocker_refused(self):
        load([windows_disk(bitlocker=True)])
        r = self.plan({"mode": "alongside", "disk": "/dev/sda", "windowsPart": "/dev/sda3", "linuxBytes": 100 * GIB})
        self.assertFalse(r["ok"])
        self.assertIn("BitLocker", r["error"])

    def test_alongside_hibernated_refused(self):
        load([windows_disk()], hibernated=True)
        r = self.plan({"mode": "alongside", "disk": "/dev/sda", "windowsPart": "/dev/sda3", "linuxBytes": 100 * GIB})
        self.assertFalse(r["ok"])

    def test_alongside_too_much_taken(self):
        load([windows_disk()], min_bytes=300 * GIB)
        r = self.plan({"mode": "alongside", "disk": "/dev/sda", "windowsPart": "/dev/sda3", "linuxBytes": 200 * GIB})
        self.assertFalse(r["ok"])

    def test_alongside_too_small_for_arch(self):
        load([windows_disk()])
        r = self.plan({"mode": "alongside", "disk": "/dev/sda", "windowsPart": "/dev/sda3", "linuxBytes": 10 * GIB})
        self.assertFalse(r["ok"])

    def test_custom_requires_root_and_efi(self):
        load([windows_disk()])
        r = self.plan({"mode": "custom", "disk": "/dev/sda", "custom": [{"part": "/dev/sda1", "role": "efi"}]})
        self.assertFalse(r["ok"])

    def test_custom_keeps_other_partitions(self):
        dev = windows_disk()
        dev["children"].append(part("/dev/sda", 4, 410000, 50 * GIB, "ext4", backend.TYPE_LINUX))
        load([dev])
        r = self.plan({"mode": "custom", "disk": "/dev/sda", "custom": [
            {"part": "/dev/sda1", "role": "efi", "format": False},
            {"part": "/dev/sda4", "role": "/", "format": True}]})
        self.assertTrue(r["ok"], r)
        cmds = [c for s in r["steps"] for c in s["cmds"]]
        self.assertFalse(any(c[0] == "mkfs.fat" for c in cmds))
        self.assertNotIn("/dev/sda3", [a for c in cmds for a in c])


class Run(unittest.TestCase):
    CH = {"mode": "erase", "disk": "/dev/vda", "dryRun": True, "lang": "uk", "layouts": ["us", "ua"],
          "wallpaper": "/home/live/.local/share/blackvarmir/wallpapers/varmir-aura.png",
          "user": {"name": "test", "fullName": "Test User", "hostname": "bvarch", "password": "s3cret-pw"}}

    def run_dry(self, ch):
        import io, contextlib
        load([disk("/dev/vda", 64 * GIB, [])])
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = backend.cmd_run(ch)
        return rc, [json.loads(line) for line in buf.getvalue().splitlines()]

    def test_dry_run_completes_without_touching_disk(self):
        backend.time.sleep = lambda *_: None
        rc, ev = self.run_dry(self.CH)
        self.assertEqual(rc, 0)
        self.assertEqual(ev[-1]["type"], "done")
        steps = next(e for e in ev if e["type"] == "steps")
        self.assertTrue(steps["dryRun"])
        self.assertIn("Install the GRUB bootloader", steps["titles"])
        self.assertEqual(sum(1 for e in ev if e["type"] == "step" and e["state"] == "ok"), len(steps["titles"]))

    def test_password_never_logged(self):
        backend.time.sleep = lambda *_: None
        _, ev = self.run_dry(self.CH)
        self.assertNotIn("s3cret-pw", json.dumps(ev))

    def test_bad_user_name_rejected(self):
        ch = json.loads(json.dumps(self.CH))
        ch["user"]["name"] = "Bad Name"
        rc, ev = self.run_dry(ch)
        self.assertEqual(rc, 1)
        self.assertEqual(ev[-1]["type"], "error")

    def test_real_run_needs_root_and_confirm(self):
        ch = dict(self.CH, dryRun=False)
        if os.geteuid() == 0:
            self.skipTest("running as root")
        rc, ev = self.run_dry(ch)
        self.assertEqual(rc, 1)
        self.assertEqual(ev[-1]["type"], "error")

    def test_settings_json_for_new_user(self):
        d = json.loads(backend.settings_json(self.CH, "test"))
        self.assertEqual(d["shellLang"], "uk")
        self.assertEqual(d["kbLayouts"], ["us", "ua"])
        self.assertEqual(d["wallpaper"], "/home/test/.local/share/blackvarmir/wallpapers/varmir-aura.png")


if __name__ == "__main__":
    unittest.main()
