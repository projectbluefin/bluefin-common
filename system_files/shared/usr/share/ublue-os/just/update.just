# vim: set ft=make :

alias upgrade := update

# Update system, flatpaks and homebrew packages all at once
update:
    #!/usr/bin/bash
    if systemctl cat -- uupd.timer &> /dev/null; then
        SERVICE="uupd.service"
    else
        SERVICE="rpm-ostreed-automatic.service"
    fi
    if systemctl is-active --quiet "$SERVICE"; then
        echo "automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
        exit 1
    fi
    if rpm-ostree status --booted 2>/dev/null | grep -q "Layered packages:"; then
        echo "Status: Layered Packages Detected"
        echo "Run an \`rpm-ostree reset\` and try again. This removes the Zero Maintenance guarantee, take appropriate precautions!"
        exit 1
    fi
    # Upgrade system image with retry for transient GHCR blob/CDN failures (#806).
    # bctl update is not used here: it exits 0 even on failure and has no retry,
    # causing silent data loss (Flatpaks/Homebrew skipped) and false success reports.
    _max_retries=3
    _delay=10
    _attempt=0
    while [[ $_attempt -lt $_max_retries ]]; do
        if sudo bootc upgrade; then
            break
        fi
        _attempt=$((_attempt + 1))
        if [[ $_attempt -lt $_max_retries ]]; then
            echo "System image update failed (attempt ${_attempt}/${_max_retries}), retrying in ${_delay}s..."
            sleep "$_delay"
            _delay=$((_delay * 2))
        else
            echo "System image update failed after ${_max_retries} attempts." >&2
            exit 1
        fi
    done
    # Updates system Flatpaks
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi
    # Update user Flatpaks
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi
    # Guard Brew if the user does not own brew/doesn't exist
    if [[ -O /var/home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Upgrade will run brew update if needed
        /var/home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi

alias auto-update := toggle-updates

# Turn automatic updates on or off
toggle-updates ACTION="prompt":
    #!/usr/bin/bash
    # Open the bluefinctl Updates panel when available
    if command -v bctl &>/dev/null; then
        exec bctl --screen updates
    fi
    CURRENT_STATE="disabled"
    if systemctl is-enabled -q rpm-ostreed-automatic.timer; then
        CURRENT_STATE="enabled"
    elif systemctl is-enabled -q uupd.timer; then
        CURRENT_STATE="enabled"
    fi

    echo "Automatic updates are currently ${CURRENT_STATE}"
    SELECTED_OPTION="$(gum choose --header="Toggle automatic updates?" "Enable" "Disable" "Cancel")"
    [[ "${SELECTED_OPTION}" == "Cancel" || "${SELECTED_OPTION}" == "" ]] && exit 0

    if systemctl cat -- uupd.timer &> /dev/null; then
        TIMER="uupd.timer"
    else
        TIMER="rpm-ostreed-automatic.timer"
    fi
    if [ "${SELECTED_OPTION}" == "Enable" ] ; then
        sudo systemctl enable "$TIMER"
        echo "Updates have been enabled"
    elif [ "${SELECTED_OPTION}" == "Disable" ] ; then
        sudo systemctl disable "$TIMER"
        echo "Updates have been disabled"
    fi
