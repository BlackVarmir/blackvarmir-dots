-- Екрани. https://wiki.hypr.land/configuring/core/monitors/
-- Перевірити назви виходів: hyprctl monitors

-- Вбудований екран: рідна роздільність, масштаб рівно 1.
-- Цілий масштаб дешевший для відеокарти, ніж дробовий (1.25, 1.5).
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })

-- Будь-який інший монітор: рідна роздільність, автоматично праворуч.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
