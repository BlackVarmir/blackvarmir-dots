-- Рух: коротко і спокійно, як у macOS. Без пружин і відскоків.
-- https://wiki.hypr.land/configuring/core/animations/
-- speed: 1 одиниця = 100 мс.

hl.config({ animations = { enabled = true } })

-- Крива Varmir з дизайн-системи: швидкий старт, м'яка зупинка
hl.curve("varmir", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 3,   bezier = "varmir" })
hl.animation({ leaf = "border",        enabled = true, speed = 3,   bezier = "varmir" })

-- Вікна: 250 мс на появу, 150 мс на закриття
hl.animation({ leaf = "windows",       enabled = true, speed = 2.5, bezier = "varmir" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2.5, bezier = "varmir", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.5, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 2.5, bezier = "varmir" })

hl.animation({ leaf = "fade",          enabled = true, speed = 1.5, bezier = "varmir" })

-- Панелі, Spotlight, центр керування: 150 мс
hl.animation({ leaf = "layersIn",      enabled = true, speed = 1.5, bezier = "varmir", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.2, bezier = "linear", style = "fade" })

-- Робочі столи: горизонтальне ковзання, 300 мс
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3,   bezier = "varmir", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "varmir", style = "slidevert" })
