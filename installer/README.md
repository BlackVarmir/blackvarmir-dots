# Установник

Інтерфейс: `home/.config/quickshell/Installer.qml` (мова, розкладка, Wi-Fi, диск, шпалери, користувач, підтвердження).
Запуск у живому сеансі: `BV_INSTALLER=1`; вручну: `qs ipc call installer show`.
`BV_DRYRUN=1` лише показує план, на диск нічого не пишеться. `BV_REPO` — де лежить репозиторій (типово `/opt/blackvarmir-dots`).

Бекенд `backend.py`: `disks` (диски, розділи, вільне місце, Windows/BitLocker) і `plan` (JSON вибору на вході → кроки й підсумок).
Нічого не пише на диск. Перевірка: `python3 -m unittest discover -s installer/tests`.
Перевіряти будь-яку логіку дисків лише на порожніх або віртуальних дисках.
