-- Автозапуск разом із сесією.
-- https://wiki.hypr.land/configuring/core/autostart/
-- Усе тут подієве: жоден процес не опитує систему щосекунди.

hl.on("hyprland.start", function()
    -- Оболонка: панель, Spotlight, сповіщення
    hl.exec_cmd("qs")

    -- Шпалери з плавним переходом
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && awww img ~/.local/share/blackvarmir/wallpapers/varmir-aura.png --transition-type fade")

    -- Блокування і сон за бездіяльності
    hl.exec_cmd("hypridle")

    -- Агент автентифікації (вікно пароля для pkexec, GParted тощо)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Історія буфера обміну (текст і картинки)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
