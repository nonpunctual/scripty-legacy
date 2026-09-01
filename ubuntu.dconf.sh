#!/bin/bash


echo "Applying system-wide GNOME privacy & security lockdown..."

fail=0
run() {
    if ! "$@"
    then
        echo "  failed: $*" >&2
        fail=1
    fi
}


# Create dconf profile (if not present)
echo "Setting up dconf profile..."
run sudo mkdir -p /etc/dconf/profile
if ! (echo -e "user-db:user\nsystem-db:local" | sudo tee /etc/dconf/profile/user > /dev/null)
then
    echo "  failed: writing /etc/dconf/profile/user" >&2
    fail=1
fi


# Create settings directory and policy file
echo "Writing dconf keyfile..."
run sudo mkdir -p /etc/dconf/db/local.d/
if ! (sudo tee /etc/dconf/db/local.d/00-security-settings > /dev/null << EOF
[org/gnome/desktop/screensaver]
lock-enabled=true
lock-delay=uint32 0
ubuntu-lock-on-suspend=true

[org/gnome/desktop/session]
idle-delay=uint32 300

[org/gnome/system/location]
enabled=false

[org/gnome/desktop/privacy]
remember-recent-files=false
remove-old-trash-files=true
old-files-age=uint32 30
EOF
)
then
    echo "  failed: writing dconf keyfile" >&2
    fail=1
fi


# Create lock file
echo "Locking keys..."
run sudo mkdir -p /etc/dconf/db/local.d/locks/
if ! (sudo tee /etc/dconf/db/local.d/locks/security-settings > /dev/null << EOF
/org/gnome/desktop/screensaver/lock-enabled
/org/gnome/desktop/screensaver/lock-delay
/org/gnome/desktop/screensaver/ubuntu-lock-on-suspend
/org/gnome/desktop/session/idle-delay
/org/gnome/system/location/enabled
/org/gnome/desktop/privacy/remember-recent-files
/org/gnome/desktop/privacy/remove-old-trash-files
/org/gnome/desktop/privacy/old-files-age
EOF
)
then
    echo "  failed: writing dconf lock file" >&2
    fail=1
fi


# Apply settings
echo "Updating dconf database..."
run sudo dconf update

if [ "$fail" -eq 0 ]
then
    echo "System-wide GNOME privacy and security settings are now enforced and locked."
else
    echo "One or more steps failed - lockdown may be incomplete, see errors above." >&2; exit 1
fi
