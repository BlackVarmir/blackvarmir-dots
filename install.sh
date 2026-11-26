#!/usr/bin/env bash
# BlackVarmir Arch — встановлення на чистий Arch Linux.
#
#   ./install.sh              звичайне встановлення
#   ./install.sh --cachyos    + оптимізовані репозиторії CachyOS (x86-64-v3) і ядро linux-cachyos
#   ./install.sh --skip-gpu   не чіпати драйвер Nvidia
#
# Скрипт можна запускати повторно: він ставить лише відсутнє і не дублює налаштування.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/blackvarmir-backup-$(date +%Y%m%d-%H%M%S)"
WITH_CACHYOS=0
SKIP_GPU=0

for arg in "$@"; do
    case "$arg" in
        --cachyos)  WITH_CACHYOS=1 ;;
        --skip-gpu) SKIP_GPU=1 ;;
        -h|--help)  sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Невідомий параметр: $arg" >&2; exit 1 ;;
    esac
done

# ── Вивід ─────────────────────────────────────────────────────────
green=$'\e[38;2;16;185;129m'; cyan=$'\e[38;2;34;211;238m'; amber=$'\e[38;2;245;158;11m'
red=$'\e[38;2;239;68;68m'; dim=$'\e[2m'; reset=$'\e[0m'
step() { printf '\n%s▍%s %s\n' "$green" "$reset" "$*"; }
info() { printf '  %s%s%s\n' "$dim" "$*" "$reset"; }
warn() { printf '  %s! %s%s\n' "$amber" "$*" "$reset"; }
die()  { printf '%s✗ %s%s\n' "$red" "$*" "$reset" >&2; exit 1; }

read_list() { grep -vE '^\s*(#|$)' "$1" | awk '{print $1}'; }

# BV_CHROOT=1: запуск установником усередині arch-chroot. Там немає працюючої systemd, D-Bus і
# udev: усе, що вимагає живої системи, пропускається, а конфігурацію snapper і знімок
# «clean install» створить перший запуск (blackvarmir-firstboot). Звичайне встановлення
# на працюючу систему цим не змінюється.
live() { [[ -z "${BV_CHROOT:-}" ]]; }
# systemctl enable, а в живій системі ще й запуск
svc_enable() { if live; then sudo systemctl enable --now "$@" >/dev/null; else sudo systemctl enable "$@" >/dev/null; fi; }

# ── Перевірки ─────────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || die "Скрипт розрахований на Arch Linux."
[[ $EUID -ne 0 ]]          || die "Запускай від звичайного користувача, не від root (sudo скрипт попросить сам)."
command -v sudo >/dev/null || die "Потрібен sudo."
curl -fsI https://archlinux.org >/dev/null 2>&1 || die "Немає інтернету."

printf '%sBlackVarmir Arch%s · Hyprland · Varmir Dark Glass\n' "$cyan" "$reset"
sudo -v

# ── 1. CachyOS (за бажанням) ──────────────────────────────────────
if (( WITH_CACHYOS )); then
    step "Репозиторії CachyOS"
    if grep -q '^\[cachyos' /etc/pacman.conf; then
        info "Вже підключені."
    else
        tmp="$(mktemp -d)"
        curl -fL https://mirror.cachyos.org/cachyos-repo.tar.xz -o "$tmp/cachyos-repo.tar.xz"
        tar -xf "$tmp/cachyos-repo.tar.xz" -C "$tmp"
        (cd "$tmp/cachyos-repo" && sudo ./cachyos-repo.sh)
        rm -rf "$tmp"
    fi
    info "Ядро linux-cachyos (старе ядро лишається як запасне в меню завантаження)"
    sudo pacman -S --needed --noconfirm linux-cachyos linux-cachyos-headers
fi

# ── 2. Пакети з офіційних репозиторіїв ────────────────────────────
step "Пакети (pacman)"
mapfile -t PKGS < <(read_list "$REPO_DIR/packages/pacman.txt")
sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"

# ── 3. AUR-помічник paru ──────────────────────────────────────────
step "AUR-помічник paru"
if command -v paru >/dev/null; then
    info "Вже встановлено."
else
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

step "Пакети (AUR)"
mapfile -t AUR < <(read_list "$REPO_DIR/packages/aur.txt")
if (( ${#AUR[@]} )); then paru -S --needed --noconfirm "${AUR[@]}"; fi

# ── 4. Відеокарти ─────────────────────────────────────────────────
step "Відеокарти"
GPUS="$(lspci -D -d ::03xx)"
info "$(printf '%s' "$GPUS" | sed 's/^/  /')"

IGPU_ADDR="$(printf '%s\n' "$GPUS" | grep -i 'intel'  | head -n1 | cut -d' ' -f1 || true)"
DGPU_ADDR="$(printf '%s\n' "$GPUS" | grep -i 'nvidia' | head -n1 | cut -d' ' -f1 || true)"

# Заголовки ядра для DKMS під кожне встановлене ядро
kernel_headers() {
    local k out=()
    for k in linux linux-lts linux-zen linux-hardened linux-cachyos; do
        if pacman -Q "$k" &>/dev/null; then out+=("$k-headers"); fi
    done
    if (( ${#out[@]} )); then printf '%s\n' "${out[@]}"; fi
}

if (( SKIP_GPU )); then
    info "Пропущено (--skip-gpu)."
elif [[ -n "$DGPU_ADDR" ]]; then
    NV_LINE="$(printf '%s\n' "$GPUS" | grep -i nvidia | head -n1)"
    mapfile -t HEADERS < <(kernel_headers)
    # Maxwell (GM), Pascal (GP), Volta (GV): основний драйвер 590+ їх більше не підтримує,
    # остання гілка — 580 (nvidia-580xx-* в AUR). Quadro P1000–P5200 у Precision 7530 — це Pascal.
    if grep -qE '\b(GM|GP|GV)[0-9]{3}' <<<"$NV_LINE"; then
        warn "Стара архітектура Nvidia (Maxwell/Pascal/Volta) → гілка драйвера 580 з AUR"
        for p in nvidia nvidia-dkms nvidia-lts nvidia-open nvidia-open-dkms; do
            if pacman -Q "$p" &>/dev/null; then sudo pacman -Rdd --noconfirm "$p"; fi
        done
        if (( ${#HEADERS[@]} )); then sudo pacman -S --needed --noconfirm "${HEADERS[@]}"; fi
        paru -S --needed --noconfirm nvidia-580xx-dkms nvidia-580xx-utils nvidia-prime
    else
        info "Сучасна Nvidia (Turing і новіші) → nvidia-open-dkms"
        sudo pacman -S --needed --noconfirm ${HEADERS[@]+"${HEADERS[@]}"} nvidia-open-dkms nvidia-utils nvidia-prime
    fi
    info "Запуск на Nvidia: prime-run <програма>. Hyprland лишається на Intel."
else
    info "Nvidia не знайдено — лише вбудована графіка."
fi

# Стабільні імена /dev/dri/igpu і /dev/dri/dgpu (їх читає ~/.config/hypr/modules/env.lua)
if [[ -n "$IGPU_ADDR" ]]; then
    RULE=/etc/udev/rules.d/90-blackvarmir-dri.rules
    {
        echo "# BlackVarmir: стабільні шляхи до відеокарт для AQ_DRM_DEVICES"
        echo "KERNEL==\"card*\", KERNELS==\"$IGPU_ADDR\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/igpu\""
        if [[ -n "$DGPU_ADDR" ]]; then
            echo "KERNEL==\"card*\", KERNELS==\"$DGPU_ADDR\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/dgpu\""
        fi
    } | sudo tee "$RULE" >/dev/null
    if live; then
        sudo udevadm control --reload
        sudo udevadm trigger --subsystem-match=drm
    fi
    info "Правило udev: $RULE"
fi

# ── 5. Системні налаштування ──────────────────────────────────────
step "Пам'ять: zram і sysctl"
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$REPO_DIR/system/etc/sysctl.d/99-blackvarmir.conf" /etc/sysctl.d/99-blackvarmir.conf
if live; then sudo sysctl --system >/dev/null; fi

step "Індекс файлів для Spotlight (plocate)"
# На btrfs підтоми (зокрема @home) виглядають для updatedb як bind-монтування
# і за замовчуванням пропускаються — тоді домашня тека не потрапила б в індекс.
if [[ "$(findmnt -no FSTYPE --target "$HOME")" == "btrfs" ]]; then
    sudo sed -i 's/^PRUNE_BIND_MOUNTS *= *"yes"/PRUNE_BIND_MOUNTS = "no"/' /etc/updatedb.conf
    info "btrfs: увімкнено індексацію підтомів (PRUNE_BIND_MOUNTS = \"no\")"
fi
# Оновлювати індекс щогодини, а не раз на добу, щоб нові файли швидше з'являлися в пошуку
sudo install -Dm644 /dev/stdin /etc/systemd/system/plocate-updatedb.timer.d/10-hourly.conf <<'EOF'
[Timer]
OnCalendar=
OnCalendar=hourly
RandomizedDelaySec=5min
EOF
if live; then
    sudo systemctl daemon-reload
    sudo updatedb && info "Індекс побудовано"
else
    info "Індекс файлів побудує таймер після першого завантаження"
fi

step "Служби"
for unit in NetworkManager bluetooth power-profiles-daemon plocate-updatedb.timer; do
    sudo systemctl enable "$unit" >/dev/null 2>&1 && info "✓ $unit" || warn "не вдалося увімкнути $unit"
done
if systemctl is-enabled display-manager.service &>/dev/null; then
    info "Менеджер входу вже налаштований — SDDM не вмикаю."
else
    sudo systemctl enable sddm >/dev/null && info "✓ sddm"
fi

step "Екран входу (тема SDDM blackvarmir)"
THEME_DIR=/usr/share/sddm/themes/blackvarmir
sudo install -d "$THEME_DIR"
sudo install -m644 "$REPO_DIR"/system/sddm/blackvarmir/{Main.qml,metadata.desktop,theme.conf} "$THEME_DIR/"
sudo install -m644 "$REPO_DIR/assets/wallpapers/varmir-aura.png" "$THEME_DIR/background.png"
sudo install -Dm644 /dev/stdin /etc/sddm.conf.d/10-blackvarmir.conf <<'EOF'
# BlackVarmir: тема екрана входу
[Theme]
Current=blackvarmir
EOF
info "Перевірити без виходу: sddm-greeter-qt6 --test-mode --theme $THEME_DIR"

step "Помічник застосунку «Налаштування»"
sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-settings-helper" /usr/local/bin/blackvarmir-settings-helper
sudo install -d /usr/share/sddm/faces
info "Зміна мови, часового поясу, кришки і аватара просить пароль через pkexec"

# ── 6. Конфіги користувача (симлінки, старі — у резервну копію) ──
step "Знімки системи (snapper) і меню завантаження"
sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-restore-cleanup" /usr/local/bin/blackvarmir-restore-cleanup
sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-bootcheck" /usr/local/bin/blackvarmir-bootcheck
sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-snapshot-info" /usr/local/bin/blackvarmir-snapshot-info
sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-grub-titles" /usr/local/bin/blackvarmir-grub-titles
if [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
    warn "корінь не на btrfs — знімки недоступні, крок пропущено"
else
    if ! live; then
        sudo install -Dm755 "$REPO_DIR/system/bin/blackvarmir-firstboot" /usr/local/bin/blackvarmir-firstboot
        sudo install -m644 "$REPO_DIR/system/systemd/blackvarmir-firstboot.service" /etc/systemd/system/
        sudo systemctl enable blackvarmir-firstboot.service >/dev/null
        info "snapper: конфігурація і знімок «clean install» при першому завантаженні"
    elif ! sudo snapper -c root get-config >/dev/null 2>&1; then
        # Розкладка archinstall уже має підтом @.snapshots у /.snapshots: snapper create-config
        # хоче створити свій, тому тимчасово прибираємо точку монтування і повертаємо наш підтом
        if mountpoint -q /.snapshots; then
            sudo umount /.snapshots
            sudo rmdir /.snapshots
            sudo snapper -c root create-config /
            sudo btrfs subvolume delete /.snapshots >/dev/null
            sudo mkdir /.snapshots
            sudo mount -a
        else
            sudo snapper -c root create-config /
        fi
        info "створено конфігурацію snapper root"
    fi
    if live; then
        # Користувач бачить і створює знімки без пароля; щоденні вимкнені, тримаємо 10
        sudo snapper -c root set-config "ALLOW_USERS=$USER" SYNC_ACL=yes TIMELINE_CREATE=no \
            NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=10
        sudo chmod 750 /.snapshots
        # Квоти btrfs: «Налаштування → Знімки» показує, скільки займають знімки, а snapper
        # прибирає старі ще й з огляду на місце
        if ! sudo btrfs qgroup show / >/dev/null 2>&1; then
            sudo btrfs quota enable /
        fi
        sudo snapper -c root setup-quota >/dev/null 2>&1 || true
    fi
    # Опис знімків: що саме оновлюється (кількість, пакети з версіями)
    sudo install -Dm644 -t /etc/pacman.d/hooks "$REPO_DIR"/system/pacman/06-blackvarmir-snapshot-*.hook
    svc_enable snapper-cleanup.timer
    sudo install -m644 "$REPO_DIR/system/systemd/blackvarmir-restore-cleanup.service" /etc/systemd/system/
    sudo systemctl enable blackvarmir-restore-cleanup.service >/dev/null
    info "✓ знімок перед кожним оновленням (snap-pac)"

    if [[ -f /boot/grub/grub.cfg ]]; then
        # Знімки в меню GRUB (grub-btrfs) і тимчасові зміни поверх знімка (overlayfs)
        sudo install -Dm644 /dev/stdin /etc/default/grub-btrfs/config <<'EOF'
GRUB_BTRFS_SUBMENUNAME="Знімки системи"
GRUB_BTRFS_TITLE_FORMAT=("description")
GRUB_BTRFS_LIMIT="20"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="false"
EOF
        if ! grep -q 'grub-btrfs-overlayfs' /etc/mkinitcpio.conf; then
            sudo sed -i -E 's/^(HOOKS=\(.*)\)/\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
            sudo mkinitcpio -P >/dev/null
        fi
        svc_enable grub-btrfsd.service
        # Назви як у дизайні: «#42 · сьогодні 14:02 · перед оновленням (23)»
        sudo install -m644 "$REPO_DIR"/system/systemd/blackvarmir-grub-titles.{path,service} /etc/systemd/system/
        if live; then sudo systemctl daemon-reload; fi
        svc_enable blackvarmir-grub-titles.path

        # Тема Varmir, шрифт з кирилицею, приховане меню (Shift / Esc або невдале минуле завантаження)
        THEME=/usr/share/grub/themes/blackvarmir
        sudo install -d "$THEME"
        sudo install -m644 "$REPO_DIR"/system/grub/blackvarmir/* "$THEME/"
        FONT="$(fc-match -f '%{file}' 'GeistMono Nerd Font:style=Regular')"
        [[ -f "$FONT" ]] && sudo grub-mkfont -s 22 -o "$THEME/font.pf2" "$FONT"
        sudo install -m755 "$REPO_DIR/system/grub/grub.d/01_blackvarmir" /etc/grub.d/01_blackvarmir
        # Пункти «BlackVarmir Arch» замість «Arch Linux, with Linux …»: свій генератор, а
        # стандартний 10_linux — заглушка, яку pacman не перезапише (NoUpgrade)
        sudo install -m755 "$REPO_DIR/system/grub/grub.d/09_blackvarmir" /etc/grub.d/09_blackvarmir
        printf '#!/bin/sh\n# Вимкнено BlackVarmir: пункти меню генерує 09_blackvarmir\nexit 0\n' | sudo tee /etc/grub.d/10_linux >/dev/null
        grep -q '^NoUpgrade.*etc/grub.d/10_linux' /etc/pacman.conf \
            || sudo sed -i '/^\[options\]/a NoUpgrade = etc/grub.d/10_linux' /etc/pacman.conf
        set_grub() {
            if grep -qE "^#?$1=" /etc/default/grub; then
                sudo sed -i -E "s|^#?$1=.*|$1=$2|" /etc/default/grub
            else
                echo "$1=$2" | sudo tee -a /etc/default/grub >/dev/null
            fi
        }
        set_grub GRUB_DISTRIBUTOR '"BlackVarmir Arch"'
        set_grub GRUB_TIMEOUT 3
        set_grub GRUB_TIMEOUT_STYLE hidden
        set_grub GRUB_THEME "\"$THEME/theme.txt\""
        [[ -f "$THEME/font.pf2" ]] && set_grub GRUB_FONT "\"$THEME/font.pf2\""
        sudo install -m644 "$REPO_DIR"/system/systemd/blackvarmir-boot-{start,ok}.service /etc/systemd/system/
        sudo systemctl enable blackvarmir-boot-start.service blackvarmir-boot-ok.service >/dev/null
        sudo grub-editenv /boot/grub/grubenv set boot_success=1
        sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
        info "✓ GRUB: знімки в меню, тема Varmir"
    elif [[ -f /boot/limine.conf || -f /boot/EFI/limine/limine.conf || -f /efi/limine.conf ]]; then
        paru -S --needed --noconfirm limine-snapper-sync
        sudo systemctl enable --now limine-snapper-sync.service >/dev/null
        info "✓ Limine: знімки в меню (limine-snapper-sync)"
    else
        info "завантажувач не GRUB і не Limine — відновлення лише з «Налаштування → Знімки»"
    fi
fi
if live; then sudo systemctl daemon-reload; fi

step "Конфіги"
mkdir -p "$HOME/.config"
link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        info "= ${dst/#$HOME/~}"
        return
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        warn "старий ${dst/#$HOME/~} → ${BACKUP_DIR/#$HOME/~}"
    fi
    ln -s "$src" "$dst"
    info "→ ${dst/#$HOME/~}"
}
for item in "$REPO_DIR"/home/.config/*; do
    link "$item" "$HOME/.config/$(basename "$item")"
done

mkdir -p "$HOME/.local/share/blackvarmir/wallpapers" "$HOME/Pictures/Screenshots"
cp -u "$REPO_DIR"/assets/wallpapers/* "$HOME/.local/share/blackvarmir/wallpapers/"
xdg-user-dirs-update

# Темна тема, іконки, шрифти і курсор для GTK-застосунків. color-scheme через портал
# бачать і Firefox, і Electron-застосунки.
if command -v gsettings >/dev/null; then
    # У chroot немає сеансу D-Bus: gsettings запускаємо в тимчасовому
    gs() { if live; then gsettings "$@"; else dbus-run-session -- gsettings "$@"; fi; }
    gs set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gs set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gs set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gs set org.gnome.desktop.interface font-name 'Geist 11'
    gs set org.gnome.desktop.interface monospace-font-name 'GeistMono Nerd Font 11'
    gs set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    gs set org.gnome.desktop.interface cursor-size 24
    gs set org.gnome.desktop.wm.preferences button-layout ':close'
fi

# Qt: стиль Fusion з палітрою Varmir. Шлях до палітри має бути повним, тому файл
# пишемо тут, а не тримаємо в репозиторії.
if [[ ! -f "$HOME/.config/qt6ct/qt6ct.conf" ]]; then
    cat > "$HOME/.config/qt6ct/qt6ct.conf" <<QT
[Appearance]
color_scheme_path=$HOME/.config/qt6ct/colors/Varmir.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed="GeistMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Geist,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
QT
    info "→ ~/.config/qt6ct/qt6ct.conf"
fi

# ── 7. fish як оболонка за замовчуванням ─────────────────────────
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    step "fish як оболонка за замовчуванням"
    chsh -s /usr/bin/fish || warn "Не вдалося. Виконай вручну: chsh -s /usr/bin/fish"
fi

# ── Готово ────────────────────────────────────────────────────────
step "Готово"
cat <<EOF
  Перезавантаж ноутбук і вибери сесію Hyprland у SDDM.

  Super + Space   Spotlight
  Super + Enter   термінал
  Super + 1…6     робочі столи
  Super + L       заблокувати

  Чеклист продуктивності: ${REPO_DIR/#$HOME/~}/docs/PERFORMANCE.md
EOF
