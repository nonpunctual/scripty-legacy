#!/bin/bash

# Upgrades fleetctl to the latest fleetdm/fleet GitHub release:
# - looks up the latest release tag via GitHub API
# - downloads the release fleetctl macOS .pkg to /private/tmp/
# - installs then deletes the .pkg. installer

# operations
if [ "$EUID" != 0 ]
then
	echo "This script must be executed as the root user. Exiting..."; exit
fi

fltver="$(/usr/bin/curl -LSs 'https://api.github.com/repos/fleetdm/fleet/releases/latest' | /usr/bin/jq -r .tag_name | /usr/bin/sed 's/fleet-v//')"
fltpkg="/private/tmp/fleetctl_v${fltver}_mac.pkg"

/usr/bin/curl -LSs -o "$fltpkg" "https://github.com/fleetdm/fleet/releases/download/fleet-v${fltver}/fleetctl_v${fltver}_mac.pkg"; /bin/sleep 2
/usr/sbin/installer -dumplog -pkg "$fltpkg" -tgt /; /bin/sleep 2
/bin/rm -f "$fltpkg"