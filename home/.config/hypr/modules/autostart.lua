-- Автозапуск разом із сесією.
-- https://wiki.hypr.land/configuring/core/autostart/
-- Усе тут подієве: жоден процес не опитує систему щосекунди.
-- Файли в ~/.config/blackvarmir/ створює застосунок «Налаштування»; якщо їх ще немає,
-- використовуються стандартні з цього репозиторію.

local cfg = "$HOME/.config/blackvarmir"

hl.on("hyprland.start", function()
    -- Оболонка: панель, Spotlight, огляд, центр керування, налаштування, сповіщення
    hl.exec_cmd("qs")

    -- Шпалери з плавним переходом (вибрані в налаштуваннях або Varmir Aura)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && awww img \"$(cat " .. cfg .. "/wallpaper 2>/dev/null || echo ~/.local/share/blackvarmir/wallpapers/varmir-aura.png)\" --transition-type fade")

    -- Блокування і сон за бездіяльності
    hl.exec_cmd("[ -f " .. cfg .. "/hypridle.conf ] && exec hypridle -c " .. cfg .. "/hypridle.conf || exec hypridle")

    -- Нічне світло за розкладом (керується з налаштувань і центру керування)
    hl.exec_cmd("[ -f " .. cfg .. "/hyprsunset.conf ] && exec hyprsunset -c " .. cfg .. "/hyprsunset.conf || exec hyprsunset")

    -- Курсор Bibata і для самого Hyprland
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- Агент автентифікації (вікно пароля для pkexec, налаштувань системи тощо)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Історія буфера обміну (текст і картинки)
    -- Історія буфера: 500 записів (паролі, позначені менеджерами як приховані, не зберігаються)
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 500 store")
    hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 500 store")
end)
