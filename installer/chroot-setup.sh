#!/usr/bin/env bash
# Налаштування нової системи всередині arch-chroot (викликається бекендом установника).
#   chroot-setup.sh <користувач> <повне імʼя> <імʼя компʼютера> <en|uk> <розкладка консолі>
# Пароль сюди не передається: його встановлює бекенд через chpasswd зі stdin.
set -euo pipefail

user="$1" full="$2" host="$3" lang="$4" keymap="$5"

[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "bad user name" >&2; exit 1; }
[[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || { echo "bad host name" >&2; exit 1; }
[[ "$full" != *:* && "$full" != *$'\n'* ]] || { echo "bad full name" >&2; exit 1; }
[[ "$keymap" =~ ^[a-z0-9_-]{1,20}$ ]] || keymap=us
case "$lang" in uk) sys_locale=uk_UA.UTF-8 ;; *) sys_locale=en_US.UTF-8 ;; esac

# Мова: англійська завжди доступна, українська додається, якщо її обрано
echo "$host" > /etc/hostname
sed -i -E 's/^#(en_US\.UTF-8 UTF-8)/\1/' /etc/locale.gen
[[ "$lang" != uk ]] || sed -i -E 's/^#(uk_UA\.UTF-8 UTF-8)/\1/' /etc/locale.gen
locale-gen
echo "LANG=$sys_locale" > /etc/locale.conf
echo "KEYMAP=$keymap" > /etc/vconsole.conf

# Час: UTC за замовчуванням, часовий пояс змінюється в «Налаштування»
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc 2>/dev/null || true

# Користувач: адміністратор (wheel). Тимчасовий sudo без пароля потрібен лише для install.sh
# під час установки, бекенд прибирає його в кінці.
useradd -m -G wheel -s /usr/bin/fish -c "$full" "$user"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-bv-install
chmod 440 /etc/sudoers.d/10-wheel /etc/sudoers.d/99-bv-install
passwd -l root >/dev/null

systemctl enable NetworkManager >/dev/null
