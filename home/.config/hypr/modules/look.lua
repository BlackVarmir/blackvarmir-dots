-- Вигляд: Varmir Dark Glass.
-- https://wiki.hypr.land/configuring/core/config-options/

local varmir = {
    emerald  = "rgba(10b981ff)",
    cyan     = "rgba(22d3eeff)",
    inactive = "rgba(ffffff14)", -- білий 8%
    canvas   = "rgb(0a0a0b)",
}

hl.config({
    general = {
        gaps_in     = 7,
        gaps_out    = 14,
        border_size = 2,

        col = {
            -- Фірмовий градієнт смарагд → ціан лише на активному вікні
            active_border   = { colors = { varmir.emerald, varmir.cyan }, angle = 45 },
            inactive_border = varmir.inactive,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        -- Вікна непрозорі: розмивати вміст під кожним вікном дорого,
        -- тому скло залишаємо лише панелям і оверлеям Quickshell (див. rules.lua).
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = 0x66000000,
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
            xray              = true, -- плаваючі вікна не перемальовують тайлові під собою
            vibrancy          = 0.17,
            popups            = false,
            special           = false,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = varmir.canvas,
        focus_on_activate        = true,
        animate_manual_resizes   = false,
        key_press_enables_dpms   = true,
        mouse_move_enables_dpms  = true,
        -- Якщо екран блокування (Quickshell) впаде, його можна перезапустити, не втративши сеанс
        allow_session_lock_restore = true,
        -- Живий розмитий робочий стіл під екраном блокування (hyprlock)
        session_lock_xray = true,
        session_lock_blur = true,
    },

    render = {
        -- Повноекранні ігри та відео в обхід композиції, коли застосунок позначає вміст як «game»
        direct_scanout = 2,
    },

    cursor = {
        inactive_timeout = 5,
        hide_on_key_press = true,
    },
})
