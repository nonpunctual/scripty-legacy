#!/bin/bash


# Checks macOS Internet Sharing state.

# /Library/Preferences/SystemConfiguration/com.apple.nat.plist is created 
# the first time Internet Sharing is turned on. The .plist persists after
# Internet Sharing is turned off.

# This script reports .plist absence (never enabled), persistence (enabled,
# but off) and enabled states.

# Usage: ./internet.sharing.check.sh


plist='/Library/Preferences/SystemConfiguration/com.apple.nat.plist'
enabled="$(/usr/libexec/PlistBuddy -c "print :NAT:Enabled" "$plist" 2> /dev/null)"

if [[ $? -ne 0 ]]
then
	echo "Internet Sharing has never been enabled on this Mac."; exit
fi

dstnm="$(/usr/libexec/PlistBuddy -c "print :NAT:SharingDevices" "$plist" | /usr/bin/sed -n '2,$p' | /usr/bin/sed '$d' | /usr/bin/xargs)"
srcnm="$(/usr/libexec/PlistBuddy -c "print :NAT:PrimaryInterface:PrimaryUserReadable" "$plist")"

if [[ "$enabled" -eq 1 ]]
then
	echo "Internet Sharing is enabled, from \"$srcnm\" to: ${dstnm:-none}"
else
	echo "Internet Sharing is disabled, but has been configured before, from \"$srcnm\" to: ${dstnm:-none}"
fi
