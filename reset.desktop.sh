#!/bin/bash


# This script uses AppleScript to close all Finder windows & force
# quit every visible foreground app. Background helpers / daemons
# are not impacted.

# This is very aggressive by design. Buyer Beware & Beware Of Dog...

# Requires Automation access to System Events - macOS should prompt for
# this automatically. If access is declined by the user, or if no prompt
# appears, System Events automation can be enabled in: 

# System Settings > Privacy & Security > Automation

# Usage: ./reset.desktop.sh


/usr/bin/osascript -e 'tell application "Finder"' -e 'repeat while window 1 exists' -e 'close window 1' -e 'end repeat' -e 'end tell'

pids=($(/usr/bin/osascript -e 'tell application "System Events" to unix id of (every process whose visible is true and name is not "Finder")' | /usr/bin/tr ',' ' '))

for p in "${pids[@]}"
do
	/bin/kill -9 "$p"
done
