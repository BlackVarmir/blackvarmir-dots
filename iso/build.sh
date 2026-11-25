#!/usr/bin/env bash
# Збирання ISO BlackVarmir Arch. Запускати на Arch Linux від звичайного користувача з sudo:
#
#   iso/build.sh            збирає iso/out/blackvarmir-arch-<дата>-x86_64.iso
#   iso/build.sh --clean    спершу стирає робочі теки (iso/work, iso/localrepo)
#
# Що робить: збирає пакети AUR з iso/aur.txt в локальний репозиторій, складає тимчасовий
# профіль (iso/profile + копія цього репозиторію в /opt/blackvarmir-dots + тема GRUB),
# запускає mkarchiso. Потрібні пакети: archiso, base-devel, git, grub, squashfs-tools,
# libisoburn, mtools, dosfstools.

set -euo pipefail

ISO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$ISO_DIR")"
WORK="$ISO_DIR/work"
OUT="$ISO_DIR/out"
LOCAL="$ISO_DIR/localrepo"
PROFILE="$WORK/profile"

green=$'\e[32m'; reset=$'\e[0m'
step() { printf '\n%s▍%s %s\n' "$green" "$reset" "$*"; }
die()  { echo "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Запускай від звичайного користувача (makepkg не працює від root); sudo потрібен лише для mkarchiso."
command -v mkarchiso >/dev/null || die "Немає mkarchiso: sudo pacman -S archiso"

if [[ "${1:-}" == "--clean" ]]; then
    sudo rm -rf "$WORK" "$LOCAL"
fi
mkdir -p "$OUT" "$LOCAL"

# ── 1. Пакети AUR → локальний репозиторій ─────────────────────────
step "AUR-пакети для образу"
while read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if compgen -G "$LOCAL/$pkg-*.pkg.tar.*" >/dev/null; then
        echo "= $pkg"
        continue
    fi
    tmp="$(mktemp -d)"
    git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$tmp/$pkg"
    (cd "$tmp/$pkg" && PKGDEST="$LOCAL" makepkg -s --noconfirm --needed)
    rm -rf "$tmp"
done < "$ISO_DIR/aur.txt"
(cd "$LOCAL" && rm -f blackvarmir-local.db* blackvarmir-local.files* \
    && repo-add -q blackvarmir-local.db.tar.gz ./*.pkg.tar.* )

# ── 2. Профіль: основа + репозиторій + тема ───────────────────────
step "Складання профілю"
sudo rm -rf "$PROFILE"
mkdir -p "$WORK"
cp -a "$ISO_DIR/profile" "$PROFILE"
sed -i "s|@LOCALREPO@|$LOCAL|" "$PROFILE/pacman.conf"

# Копія репозиторію всередині образу: з неї живий сеанс бере конфіги, а установник запускає install.sh
dest="$PROFILE/airootfs/opt/blackvarmir-dots"
mkdir -p "$dest"
git -C "$REPO_DIR" ls-files -z --cached --others --exclude-standard \
    | grep -zv '^iso/' | rsync -a --from0 --files-from=- "$REPO_DIR/" "$dest/"

# Тема GRUB і шрифт Geist (якщо немає, меню покаже стандартний шрифт)
theme="$PROFILE/grub/themes/blackvarmir"
mkdir -p "$theme"
cp "$REPO_DIR"/system/grub/blackvarmir/* "$theme/"
# Шрифт Geist беремо з щойно зібраного пакета ttf-geist
fonttmp="$(mktemp -d)"
for pkgfile in "$LOCAL"/ttf-geist-*.pkg.tar.*; do
    [[ -e "$pkgfile" ]] && bsdtar -xf "$pkgfile" -C "$fonttmp" usr/share/fonts 2>/dev/null || true
done
font="$(find "$fonttmp" \( -iname 'Geist-Regular.*' -o -iname 'Geist\[*' \) \( -name '*.ttf' -o -name '*.otf' \) | head -1)"
if [[ -n "$font" ]]; then
    grub-mkfont -s 22 -o "$theme/font.pf2" "$font"
else
    echo "Шрифт Geist не знайдено: меню GRUB використає стандартний"
fi
rm -rf "$fonttmp"

# ── 3. Образ ──────────────────────────────────────────────────────
step "mkarchiso"
sudo mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

step "Готово"
ls -lh "$OUT"/*.iso
iso="$(find "$OUT" -name '*.iso' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d" " -f2-)"
echo "Перевірка без флешки: run_archiso -u -i $iso"
