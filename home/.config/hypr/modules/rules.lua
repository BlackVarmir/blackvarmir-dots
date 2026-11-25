-- Правила вікон, шарів і робочих столів.
-- https://wiki.hypr.land/configuring/core/rules/

------------------------------------------------------------
-- Робочі столи: шість постійних, щоб панель завжди показувала 1–6
------------------------------------------------------------
for i = 1, 6 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

------------------------------------------------------------
-- Шари Quickshell: скло з розмиттям
-- Назви збігаються з WlrLayershell.namespace у ~/.config/quickshell
------------------------------------------------------------
hl.layer_rule({
    name         = "varmir-glass",
    match        = { namespace = "^varmir-(bar|spotlight|notifications|control|overview|osd|alttab|clipboard|calendar|capture-toast|updates|snapshot-banner)$" },
    blur         = true,
    ignore_alpha = 0.2, -- не розмивати прозорі ділянки між «острівцями»
})

------------------------------------------------------------
-- Вікна
------------------------------------------------------------

-- Ігнорувати запити застосунків «розгорнути себе» — тайлінг керує розміром сам
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Виправлення перетягування в XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Діалоги і дрібні утиліти: плаваючі, по центру
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator|xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
    size   = { "monitor_w * 0.45", "monitor_h * 0.6" },
})

-- Вікно «Налаштування» (Quickshell): плаваюче, по центру
hl.window_rule({
    name   = "varmir-settings",
    match  = { class = "^org.quickshell$" },
    float  = true,
    center = true,
    size   = { 1280, 820 },
})

-- Плаваючий термінал (Super + Shift + Enter)
hl.window_rule({
    name   = "floating-kitty",
    match  = { class = "^kitty-float$" },
    float  = true,
    center = true,
    size   = { "monitor_w * 0.5", "monitor_h * 0.55" },
})

-- Не гасити екран, поки відео або гра на весь екран
hl.window_rule({
    name  = "idle-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})
