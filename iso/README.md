# Образ BlackVarmir Arch (archiso)

Завантажувальний ISO для UEFI. Збирається на Arch Linux:

```bash
sudo pacman -S archiso base-devel git grub squashfs-tools libisoburn mtools dosfstools
iso/build.sh            # результат: iso/out/blackvarmir-arch-<дата>-x86_64.iso
iso/build.sh --clean    # спершу стерти iso/work і iso/localrepo
run_archiso -u -i iso/out/*.iso   # швидка перевірка в QEMU (пакет archiso)
```

## Що всередині

- `profile/` — профіль archiso: пакети (`packages.x86_64`), живий користувач `live` без пароля з автологіном на tty1, служби (NetworkManager, ключі pacman), меню GRUB (`grub/grub.cfg`).
- `aur.txt` — пакети AUR (ttf-geist, bibata-cursor-theme-bin); скрипт збирає їх у локальний репозиторій `iso/localrepo`.
- `build.sh` — збирає AUR-пакети, кладе копію цього репозиторію в `/opt/blackvarmir-dots`, додає тему GRUB і шрифт, запускає `mkarchiso`.

## Меню завантаження

Install BlackVarmir Arch · Try without installing · Safe graphics mode (nomodeset) · Memory test · UEFI firmware settings · Restart · Shut down. Режим береться з параметра ядра `bv.mode=install|try`.

## Живий сеанс

`blackvarmir-live-session` розгортає конфіги з `/opt/blackvarmir-dots` у `~`, вимикає привітання, блокування і сон і запускає Hyprland з тією ж оболонкою. У режимі `install` разом із сеансом стартує `blackvarmir-installer` (поки заглушка з інструкцією; графічний установник з дошки «Етап 8» додається наступними змінами).

## Чого ще нема

Графічний установник, розмітка диска (поруч із Windows, власна, BitLocker), перший знімок «Чиста установка». Образ не перевірявся на живому залізі: збирання потребує Arch Linux з правами root для `mkarchiso`.
