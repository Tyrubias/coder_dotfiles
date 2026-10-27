fish_config theme choose "Dracula Official"

set --global fish_greeting
set --global --export BAT_THEME Dracula

function fish_title
    printf '%s: %s\n' (hostname -s) (prompt_pwd)
end

if status is-interactive
    if not set --query HOMEBREW_PREFIX
        /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
    end
    
    if type --query atuin
        atuin init fish | source
    end

    if type --query direnv
        direnv hook fish | source
    end
end
