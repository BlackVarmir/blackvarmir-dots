# shellcheck shell=sh
# На першій консолі автологіну живого користувача запускаємо сеанс Hyprland.
if [ "$(id -un)" = live ] && [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ]; then
    exec /usr/local/bin/blackvarmir-live-session
fi
