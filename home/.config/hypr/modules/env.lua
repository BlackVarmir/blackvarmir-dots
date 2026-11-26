-- Змінні оточення.
-- https://wiki.hypr.land/configuring/core/environment-variables/

-- Рендер на вбудованій графіці Intel: менша затримка, тихіші вентилятори, довша батарея.
-- Nvidia лишається другою в списку, щоб працювали зовнішні монітори, підключені до неї,
-- а CUDA (моделі Varmir) використовує її напряму.
-- Стабільні симлінки /dev/dri/igpu і /dev/dri/dgpu створює install.sh через правило udev.
local function exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

if exists("/dev/dri/igpu") then
    local devices = "/dev/dri/igpu"
    if exists("/dev/dri/dgpu") then
        devices = devices .. ":/dev/dri/dgpu"
    end
    hl.env("AQ_DRM_DEVICES", devices)
end

-- Курсор
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt-застосунки беруть палітру Varmir, шрифти і значки з qt6ct
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Нативний Wayland для Qt і Electron (VS Code, Discord, Obsidian тощо)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Апаратне декодування відео на Intel (VA-API)
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Віртуальна машина (VMware, VirtualBox, QEMU): віртуальна відеокарта не вміє
-- передавати буфери застосунків у Hyprland, і Qt та kitty падають з помилкою
-- «invalid arguments for wl_surface.attach». Застосунки малюють програмно (llvmpipe),
-- на справжньому залізі нічого не змінюється.
if require("modules/vm") then
    hl.env("LIBGL_ALWAYS_SOFTWARE", "1")
end
