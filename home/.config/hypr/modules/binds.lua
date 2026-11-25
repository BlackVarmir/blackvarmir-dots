-- Гарячі клавіші. https://wiki.hypr.land/configuring/core/binds/
-- Головний модифікатор — Super (клавіша Windows).

local mod      = "SUPER"
local terminal = "kitty"

local function bind(keys, action, flags)
    hl.bind(keys, action, flags)
end

------------------------------------------------------------
-- Оболонка Quickshell (керується через qs ipc)
------------------------------------------------------------
bind(mod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call spotlight toggle"))

bind(mod .. " + TAB",          hl.dsp.exec_cmd("qs ipc call overview toggle"))
bind(mod .. " + N",            hl.dsp.exec_cmd("qs ipc call control toggle"))
-- Швидко повернутися на попередній стіл (без огляду)
bind(mod .. " + grave",        hl.dsp.focus({ workspace = "previous" }))

------------------------------------------------------------
-- Застосунки
------------------------------------------------------------
bind(mod .. " + RETURN",         hl.dsp.exec_cmd(terminal))
bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(terminal .. " --class kitty-float"))
bind(mod .. " + E",              hl.dsp.exec_cmd("nautilus --new-window"))
bind(mod .. " + V",              hl.dsp.exec_cmd(
    terminal .. " --class kitty-float -e sh -c 'cliphist list | fzf --no-sort --reverse | cliphist decode | wl-copy'"))

------------------------------------------------------------
-- Вікна
------------------------------------------------------------
bind(mod .. " + Q",             hl.dsp.window.close())
bind(mod .. " + F",             hl.dsp.window.fullscreen({ action = "toggle" }))
bind(mod .. " + M",             hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }))
bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + C",             hl.dsp.window.center())
bind(mod .. " + J",             hl.dsp.layout("togglesplit"))

-- Фокус і обмін місцями: стрілки
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. dir,         hl.dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.swap({ direction = dir }))
end

-- Перетягування і зміна розміру мишею
bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

------------------------------------------------------------
-- Робочі столи 1–6
------------------------------------------------------------
for i = 1, 6 do
    bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
end

bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Чернетка (прихований стіл): Super + S
bind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

------------------------------------------------------------
-- Система
------------------------------------------------------------
bind(mod .. " + L",           hl.dsp.exec_cmd("loginctl lock-session"))
bind(mod .. " + SHIFT + R",   hl.dsp.reload_config())
bind(mod .. " + SHIFT + E",   hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Знімки екрана: область → буфер обміну і ~/Pictures/Screenshots
local shot = "mkdir -p ~/Pictures/Screenshots && grim %s - | tee ~/Pictures/Screenshots/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png | wl-copy"
bind("Print",         hl.dsp.exec_cmd(string.format(shot, '-g "$(slurp -d)"')))
bind("SHIFT + Print", hl.dsp.exec_cmd(string.format(shot, "")))

-- Мультимедійні клавіші ноутбука (працюють і на заблокованому екрані)
local media = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media)
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      media)
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  media)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  media)
bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
