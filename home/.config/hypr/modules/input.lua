-- Клавіатура, миша, тачпад, жести.
-- https://wiki.hypr.land/configuring/core/config-options/#input

hl.config({
    input = {
        -- Англійська + українська. Перемикання Alt + Shift — прив'язкою в binds.lua,
        -- а не опцією xkb: так під час Alt + Tab мова не перемикається.
        kb_layout  = "us,ua",
        kb_options = "",

        -- Швидший повтор клавіш, як у macOS
        repeat_delay = 300,
        repeat_rate  = 40,

        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "adaptive",

        touchpad = {
            natural_scroll       = true, -- прокрутка «за вмістом», як у macOS
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true, -- 2 пальці = права кнопка
            scroll_factor        = 0.6,
        },
    },

    gestures = {
        workspace_swipe_create_new = false,
    },
})

-- Три пальці вбік: попередній / наступний робочий стіл
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
