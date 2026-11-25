# BlackVarmir Arch

Arch Linux + Hyprland у стилі **Varmir Dark Glass**: темне полотно, градієнт смарагд → ціан, скляні панелі з розмиттям, шрифт Geist. Головне — швидкість.

- **Hyprland 0.55+** з конфігом у форматі Lua
- **Quickshell**: панель-«острівці», Spotlight, огляд столів із доком, центр керування, сповіщення. Усе на подіях, без опитування
- **hyprlock / hypridle**: блокування з живим розмитим робочим столом
- **kitty + fish + starship** у тій самій палітрі
- Тонке налаштування під ноутбук з Intel + Nvidia (Dell Precision 7530): рендер на Intel, Nvidia для CUDA

## Встановлення

1. Встанови базовий Arch (`archinstall`, профіль **Minimal**, мережа NetworkManager).
2. Увійди під своїм користувачем і виконай (або скопіюй папку з флешки замість `git clone`):

```bash
sudo pacman -S --needed git
git clone https://github.com/BlackVarmir/blackvarmir-dots.git ~/blackvarmir-dots
cd ~/blackvarmir-dots
./install.sh            # або ./install.sh --cachyos для оптимізованих пакетів
```

3. Перезавантаж ноутбук і вибери сесію **Hyprland** у SDDM.

Скрипт можна запускати повторно. Старі конфіги він переносить у `~/.config/blackvarmir-backup-<дата>`, а нові підключає симлінками на цей репозиторій. Після `git pull` зміни підхоплюються одразу.

## Гарячі клавіші

| Клавіші | Дія |
|---|---|
| `Super + Space` | Spotlight (`=` калькулятор, `>` команда, `?` пошук у вебі) |
| `Super + Enter` | Термінал |
| `Super + Shift + Enter` | Плаваючий термінал |
| `Super + Q` | Закрити вікно |
| `Super + 1…6` | Робочий стіл |
| `Super + Shift + 1…6` | Перенести вікно на стіл |
| `Super + Tab` | Огляд столів із доком: пошук, перетягування вікон між столами |
| `Super + N` | Центр керування (або клік по правому «острівцю» панелі) |
| `` Super + ` `` | Попередній стіл |
| `Super + ← → ↑ ↓` | Фокус · з `Shift` — поміняти вікна місцями |
| `Super + F` / `Super + M` | На весь екран / розгорнути |
| `Super + Shift + Space` | Зробити вікно плаваючим |
| `Super + S` | Чернетка (прихований стіл) |
| `Super + V` | Історія буфера обміну |
| `Super + E` | Файли |
| `Super + L` | Заблокувати |
| `Print` / `Shift + Print` | Знімок області / всього екрана → буфер і `~/Pictures/Screenshots` |
| `Alt + Shift` | Розкладка EN ↔ UK |
| Три пальці вбік | Перемкнути стіл |

## Структура

```
install.sh                  встановлення
packages/pacman.txt         пакети з офіційних репозиторіїв
packages/aur.txt            пакети з AUR (драйвер Nvidia скрипт додає сам)
home/.config/
  hypr/hyprland.lua         точка входу Hyprland
  hypr/modules/*.lua        env · monitors · look · animations · input · rules · binds · autostart
  hypr/hyprlock.conf        екран блокування
  hypr/hypridle.conf        бездіяльність і сон
  quickshell/               оболонка: Theme (кольори, закріплені в доці застосунки) · Bar · Spotlight ·
                            Overview · ControlCenter (+ підменю Cc*) · Notifications · NotifStore · Sys
  kitty/ fish/ starship.toml
system/etc/                 zram і sysctl
assets/wallpapers/          шпалери Varmir Aura
docs/PERFORMANCE.md         чеклист продуктивності
```

Кольори, шрифти, радіуси і тривалості анімацій оболонки задаються в одному файлі: `quickshell/Theme.qml`. Для Hyprland вони в `hypr/modules/look.lua` і `animations.lua`.

## Далі

- [x] Огляд робочих столів із доком (`Super + Tab`)
- [x] Центр керування: Wi-Fi, Bluetooth, звук, яскравість, плеєр, живлення, історія сповіщень (`Super + N`)
- [ ] Закріплення застосунків у доці правою кнопкою (поки що список у `quickshell/Theme.qml`)
- [ ] Тема SDDM у тому ж стилі
- [ ] Пошук файлів у Spotlight через `plocate`
