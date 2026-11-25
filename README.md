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
| `Super + Space` | Spotlight: застосунки і файли. `/` лише файли (`Shift + Enter` — показати в теці), `=` калькулятор, `>` команда, `?` пошук у вебі |
| `Super + Enter` | Термінал |
| `Super + Shift + Enter` | Плаваючий термінал |
| `Super + Q` | Закрити вікно |
| `Alt + Tab` | Перемикач вікон: останні використані першими, з усіх столів. Швидке натискання — одразу попереднє вікно. `Shift` — назад, `Q` — закрити вибране |
| `` Alt + ` `` | Те саме, лише вікна поточного застосунку |
| `Super + 1…6` | Робочий стіл |
| `Super + Shift + 1…6` | Перенести вікно на стіл |
| `Super + Tab` | Огляд столів із доком: пошук, перетягування вікон між столами. Права кнопка на значку дока — меню |
| `Super + N` | Центр керування (або клік по правому «острівцю» панелі) |
| `` Super + ` `` | Попередній стіл |
| `Super + ← → ↑ ↓` | Фокус · з `Shift` — поміняти вікна місцями |
| `Super + F` / `Super + M` | На весь екран / розгорнути |
| `Super + Shift + Space` | Зробити вікно плаваючим |
| `Super + S` | Чернетка (прихований стіл) |
| `Super + V` | Історія буфера обміну |
| `Super + E` | Файли |
| `Super + L` | Заблокувати |
| `Super + ,` | Налаштування |
| `Print` / `Shift + Print` | Знімок області / всього екрана → буфер і `~/Pictures/Screenshots` |
| `Alt + Shift` | Наступна розкладка (комбінацію можна змінити в налаштуваннях) |
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
                            Overview · ControlCenter (+ підменю Cc*) · Notifications · NotifStore · Sys ·
                            SettingsWindow (+ сторінки Set*) · Settings · Tr + Strings (переклад)
  kitty/ fish/ starship.toml
system/etc/                 zram і sysctl
system/bin/                 blackvarmir-settings-helper: дії налаштувань, що потребують root (через pkexec)
scripts/check-strings.py    перевірка, що всі рядки оболонки перекладені
system/sddm/blackvarmir/    тема екрана входу (SDDM, Qt 6)
assets/wallpapers/          шпалери Varmir Aura
docs/PERFORMANCE.md         чеклист продуктивності
```

Кольори, шрифти, радіуси і тривалості анімацій оболонки задаються в одному файлі: `quickshell/Theme.qml`. Там же список застосунків, закріплених у доці за замовчуванням (далі його змінюєш з меню дока). Для Hyprland вони в `hypr/modules/look.lua` і `animations.lua`.

Екран входу перевіряється без виходу з системи: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/blackvarmir`.

## Індикатори, блокування, вигляд застосунків

- **Індикатори** гучності, мікрофона, яскравості екрана і підсвітки клавіатури та розкладки з'являються внизу по центру на 1,5 с. Вони реагують на саму зміну значення, тож працюють і від клавіш `Fn`, які ноутбук обробляє сам.
- **Екран блокування** — частина оболонки (`quickshell/Lock.qml`, протокол ext-session-lock). hypridle блокує через `qs ipc call lock lock`; якщо оболонка не запущена, відкривається hyprlock. Перед сном система чекає, доки екран справді заблокується.
- **GTK- і Qt-застосунки** вбрані в ті самі кольори: GTK — тема adw-gtk3-dark і `gtk.css` з акцентом Varmir, Qt — qt6ct зі стилем Fusion і палітрою `qt6ct/colors/Varmir.conf`. Шрифт Geist, значки Papirus-Dark, курсор Bibata.

Якщо оболонка впаде на заблокованому екрані, сеанс лишиться заблокованим (суцільне тло). Перейди в консоль `Ctrl + Alt + F3`, увійди і виконай `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`, потім повернись `Ctrl + Alt + F1` (або `F2`) і розблокуй паролем.

## Налаштування

`Super + ,`, шестірня в центрі керування або «Налаштування» в Spotlight. Розділи: мова і регіон, клавіатура, екран, вигляд, звук, живлення, користувач, про систему.

Те, що ти змінюєш, лежить окремо від репозиторію, тож `git pull` нічого не перезапише:

```
~/.config/blackvarmir/settings.json        усі значення
~/.config/blackvarmir/hyprland-user.lua    розкладки, монітори, відступи, розмиття, анімації (hyprland.lua підхоплює його останнім)
~/.config/blackvarmir/hypridle.conf        тайм-аути приглушення, блокування і сну
~/.config/blackvarmir/hyprsunset.conf      розклад нічного світла
~/.config/blackvarmir/wallpaper            шлях до шпалер
```

Зміни застосовуються одразу через `hyprctl eval`. Нові параметри екрана треба підтвердити за 15 секунд, інакше вони повертаються. Мова системи, часовий пояс, кришка ноутбука, ім'я і фото для екрана входу міняються через `pkexec` і помічник `blackvarmir-settings-helper`, який приймає лише перелічені дії й перевіряє значення.

Оболонка перекладена українською та англійською; мову обираєш у «Мова і регіон» (за замовчуванням як у системі). Щоб додати мову, скопіюй словник `en` у `quickshell/Strings.qml`, переклади і додай код у `Tr.languages`. `python3 scripts/check-strings.py` покаже, яких рядків бракує.

## Далі

- [x] Огляд робочих столів із доком (`Super + Tab`)
- [x] Центр керування: Wi-Fi, Bluetooth, звук, яскравість, плеєр, живлення, історія сповіщень (`Super + N`)
- [x] Меню дока правою кнопкою: вікна застосунку, його дії, закріплення і порядок (зберігається в `~/.local/state/blackvarmir/dock.json`)
- [x] Тема SDDM у тому ж стилі
- [x] Пошук файлів у Spotlight через `plocate` (індекс оновлюється щогодини)
- [x] Застосунок «Налаштування» і переклад оболонки (українська, англійська)
- [x] Індикатори, Alt + Tab, екран блокування на Quickshell, однаковий вигляд GTK і Qt
