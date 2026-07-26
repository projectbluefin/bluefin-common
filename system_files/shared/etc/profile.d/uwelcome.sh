#!/usr/bin/env bash

if [ -e ~/.config/no-show-user-motd ]; then
	mv ~/.config/no-show-user-motd ~/.config/uwelcome/disabled 2>/dev/null
fi
uwelcome
