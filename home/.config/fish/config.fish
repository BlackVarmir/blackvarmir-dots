# fish · BlackVarmir

# Без привітання при кожному відкритті термінала
set -g fish_greeting

if status is-interactive
    # Кольори підсвітки команд у тон Varmir
    set -g fish_color_command 10b981
    set -g fish_color_param fafafa
    set -g fish_color_quote 22d3ee
    set -g fish_color_error ef4444
    set -g fish_color_autosuggestion 52525b
    set -g fish_color_comment 71717a
    set -g fish_color_operator f59e0b

    # Короткі команди
    abbr -a ls 'eza --icons --group-directories-first'
    abbr -a ll 'eza -la --icons --group-directories-first --git'
    abbr -a cat 'bat --style=plain'
    abbr -a up 'paru -Syu'
    abbr -a hr 'hyprctl reload'

    # Prompt
    starship init fish | source
    # Розумний cd: z проєкт
    zoxide init fish | source
end
