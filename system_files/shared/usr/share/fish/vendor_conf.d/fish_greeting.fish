function fish_greeting

    if test -e ~/.config/no-show-user-motd
        mkdir -p ~/.config/uwelcome
        mv ~/.config/no-show-user-motd ~/.config/uwelcome/disabled 2>/dev/null
    end

    uwelcome
end
