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
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=drm
    info "Правило udev: $RULE"
fi

# ── 5. Системні налаштування ──────────────────────────────────────
step "Пам'ять: zram і sysctl"
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$REPO_DIR/system/etc/sysctl.d/99-blackvarmir.conf" /etc/sysctl.d/99-blackvarmir.conf
sudo sysctl --system >/dev/null

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

# ── 6. Конфіги користувача (симлінки, старі — у резервну копію) ──
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

# Темна тема, іконки і шрифти для GTK-застосунків
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface font-name 'Geist 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'GeistMono Nerd Font 11'
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
