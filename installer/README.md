# Установник

Інтерфейс: `home/.config/quickshell/Installer.qml` (мова, розкладка, Wi-Fi, диск, шпалери, користувач, підтвердження).
Запуск у живому сеансі: `BV_INSTALLER=1`; вручну: `qs ipc call installer open`.
`BV_DRYRUN=1` лише показує план, на диск нічого не пишеться. `BV_REPO` — де лежить репозиторій (типово `/opt/blackvarmir-dots`).

Бекенд `backend.py`: `disks` (диски, розділи, вільне місце, Windows/BitLocker) і `plan` (JSON вибору на вході → кроки й підсумок).
Нічого не пише на диск. Перевірка: `python3 -m unittest discover -s installer/tests`.
Перевіряти будь-яку логіку дисків лише на порожніх або віртуальних дисках.

## Виконання встановлення

`backend.py run` (від root, з `"confirm": true`) виконує план: розмітка і Btrfs (@, @home, @snapshots), `pacstrap`
(мінімум + AUR-пакети з `/opt/blackvarmir-localrepo`), `genfstab`, `chroot-setup.sh` (мова, користувач, hostname),
GRUB (UEFI, os-prober), `install.sh` у chroot (`BV_CHROOT=1`), прибирання тимчасового sudo. Snapper і знімок
«Чиста установка» створює `blackvarmir-firstboot.service` при першому завантаженні (у chroot немає D-Bus).
З `"dryRun": true` (або `BV_DRYRUN=1` в оболонці) нічого не виконується, лише показується хід.
Перевіряти на порожньому або віртуальному диску, ніколи на диску з важливими даними.
