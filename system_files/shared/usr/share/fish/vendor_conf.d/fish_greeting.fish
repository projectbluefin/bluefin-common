function fish_greeting

    if test -e ~/.config/no-show-user-motd
        mv ~/.config/no-show-user-motd ~/.config/uwelcome/disabled
    end

    uwelcome
end
