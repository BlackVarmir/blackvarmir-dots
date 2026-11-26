-- Чи працює система у віртуальній машині.
-- Визначаємо за прапорцем «hypervisor» у /proc/cpuinfo: його виставляє будь-який гіпервізор.
-- Команди (systemd-detect-virt) тут не годяться: os.execute усередині Hyprland не повертає код.
local f = io.open("/proc/cpuinfo", "r")
if not f then
    return false
end
local info = f:read("*a") or ""
f:close()
return info:find("flags[^\n]*%shypervisor") ~= nil
