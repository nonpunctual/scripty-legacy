#!/bin/bash


# Remove stale Internet Sharing network service entries from the SystemConfiguration preferences plist.
#
# Usage: sudo ./network.service.delete.sh <pattern> [pattern ...]
#   e.g. sudo ./network.service.delete.sh iphone ipad belkin


# variables
plist="/Library/Preferences/SystemConfiguration/preferences.plist"
services="$(/usr/bin/plutil -extract NetworkServices json -o - "$plist" | /usr/bin/jq -r 'to_entries[] | select(.value.UserDefinedName != null) | "\(.key)\t\(.value.UserDefinedName | ascii_downcase)"')"

patterns=()
for arg in "$@"
do
	patterns+=("$(printf '%s' "$arg" | tr '[:upper:]' '[:lower:]')")
done


# exit conditions
if [[ "$EUID" -ne 0 ]]
then
	echo "This script must be executed as the root user. Exiting..."; exit 1
fi

if [[ "${#patterns[@]}" -eq 0 ]] || [[ ! -r "$plist" ]]
then
	echo "No arguments supplied  or .plist could not be read. Exiting..."; exit 1
fi


# operations
while IFS=$'\t' read -r id name
do
	[[ -z "$id" ]] && continue

	for p in "${patterns[@]}"
	do
		if [[ "$name" == *"$p"* ]]
		then
			/usr/libexec/PlistBuddy -c "delete :NetworkServices:$id" "$plist"
			break
		fi
	done
done <<< "$services"
/bin/launchctl kickstart -k system/com.apple.configd
