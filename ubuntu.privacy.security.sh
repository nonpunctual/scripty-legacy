#!/bin/bash

echo "Applying Ubuntu GNOME privacy and security settings..."

fail=0
run() {
    if ! "$@"
    then
        echo "  failed: $*" >&2
        fail=1
    fi
}

# Lock screen immediately when screensaver activates
run gsettings set org.gnome.desktop.screensaver lock-enabled true
run gsettings set org.gnome.desktop.screensaver lock-delay 0

# Set screen to lock after 5 minutes of inactivity
run gsettings set org.gnome.desktop.session idle-delay 300

# Enable lock on suspend
run gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend true

# Disable file indexing (Tracker3)
run gsettings set org.freedesktop.Tracker3.Miner.Files enable-monitors false
run gsettings set org.freedesktop.Tracker3.Miner.Files crawling-interval -2

# Disable location services
run gsettings set org.gnome.system.location enabled false

# Disable recent file history
run gsettings set org.gnome.desktop.privacy remember-recent-files false

# Automatically delete trash files older than 30 days
run gsettings set org.gnome.desktop.privacy remove-old-trash-files true
run gsettings set org.gnome.desktop.privacy old-files-age 30

# Disable Apport (error reporting)
if [ -f /etc/default/apport ]
then
    run sudo sed -i 's/^enabled=.*/enabled=0/' /etc/default/apport
    run sudo systemctl stop apport.service
    run sudo systemctl disable apport.service
fi

if [ "$fail" -eq 0 ]
then
    echo "All settings applied successfully."
else
    echo "One or more settings failed to apply - see errors above." >&2; exit 1
fi
