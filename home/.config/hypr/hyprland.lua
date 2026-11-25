-- BlackVarmir Arch · Hyprland 0.55+ (Lua-конфіг)
-- Тема: Varmir Dark Glass. Кожен розділ лежить в окремому файлі в modules/.
-- Після змін: hyprctl reload (або Super + Shift + R).

require("modules/env")        -- змінні оточення, вибір відеокарти
require("modules/monitors")   -- екрани
require("modules/look")       -- відступи, рамки, розмиття, тіні
require("modules/animations") -- крива руху Varmir
require("modules/input")      -- клавіатура, тачпад, жести
require("modules/rules")      -- правила вікон, шарів і робочих столів
require("modules/binds")      -- гарячі клавіші
require("modules/autostart")  -- що запускається разом із сесією

-- Налаштування з застосунку «Налаштування» (Super + ,) — поверх усього вище.
-- Файл лежить поза репозиторієм, тож git pull його не зачіпає.
local user = (os.getenv("HOME") or "") .. "/.config/blackvarmir/hyprland-user.lua"
local f = io.open(user, "r")
if f then
    f:close()
    dofile(user)
end
