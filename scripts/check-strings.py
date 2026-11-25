#!/usr/bin/env python3
"""Перевіряє переклади оболонки: кожен ключ Tr.t()/Tr.plural() є в кожному словнику Strings.qml.

Запуск з кореня репозиторію: python3 scripts/check-strings.py
Ключі, що збираються динамічно ("set." + id), перелічено в DYNAMIC нижче.
"""
import pathlib
import re
import sys

QS = pathlib.Path(__file__).resolve().parent.parent / "home/.config/quickshell"

DYNAMIC = {f"set.{s}" for s in ("lang", "keyboard", "display", "appearance", "sound", "power", "user", "about")} | {
    f"about.{s}" for s in ("device", "cpu", "memory", "gpu", "disk", "kernel", "hyprland", "quickshell", "uptime")
}

used = set(DYNAMIC)
for f in QS.glob("*.qml"):
    if f.name == "Strings.qml":
        continue
    used |= set(re.findall(r'Tr\.t\("([\w.]+)"', f.read_text(encoding="utf-8")))
    used |= set(re.findall(r'Tr\.plural\([^,]+,\s*"([\w.]+)"', f.read_text(encoding="utf-8")))
    used |= set(re.findall(r'\["(about\.\w+)"', f.read_text(encoding="utf-8")))

used = {k for k in used if not k.endswith(".")}
src = (QS / "Strings.qml").read_text(encoding="utf-8")
dicts = {}
for m in re.finditer(r"readonly property var (\w+): \(\{(.*?)\n    \}\)", src, re.S):
    dicts[m.group(1)] = re.findall(r'^\s*"([\w.]+)":', m.group(2), re.M)

ok = True
for lang, keys in dicts.items():
    keyset = set(keys)
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    missing = sorted(used - keyset)
    unused = sorted(keyset - used)
    if dupes:
        ok = False
        print(f"[{lang}] повтори: {', '.join(dupes)}")
    if missing:
        ok = False
        print(f"[{lang}] бракує: {', '.join(missing)}")
    if unused:
        print(f"[{lang}] не використовуються: {', '.join(unused)}")
    print(f"[{lang}] ключів: {len(keyset)}")

# Плейсхолдери {0} мають збігатися між мовами
base = dict(re.findall(r'^\s*"([\w.]+)":\s*"(.*)",?$', src.split("readonly property var en")[0], re.M))
other = dict(re.findall(r'^\s*"([\w.]+)":\s*"(.*)",?$', src.split("readonly property var en")[1], re.M))
for k, v in base.items():
    if k in other and sorted(re.findall(r"\{\d\}", v)) != sorted(re.findall(r"\{\d\}", other[k])):
        ok = False
        print(f"підстановки різняться: {k}")

print("OK" if ok else "Є помилки")
sys.exit(0 if ok else 1)
