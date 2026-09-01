#!/bin/bash


# mdm.managed.users @2025 Fleet Device Management
# Brock Walters (brock@fleetdm.com)

# set -x
# trap read debug


if [ "$EUID" != 0 ]
then
	echo "This script must be executed as the root user. Exiting..."; exit
fi


mdmdump="$(/usr/libexec/mdmclient DumpManagementStatus)"
mdminfo="$(/usr/libexec/mdmclient QueryDeviceInformation | /usr/bin/sed '/^=== CPF_GetInstalledProfiles === (<Device>)/d;/^Number of <Device> profiles found: /d')"
agntrsp="$(echo "$mdminfo" | /usr/bin/awk '/^Agent response: {/{flag=1;next}/^}$/{flag=0}flag && $0 !~ /= \{length = /')"
dmonrsp="$(echo "$mdminfo" | /usr/bin/awk '/^Daemon response: {/{flag=1;next}/^}$/{flag=0}flag && $0 !~ /= \{length = /')"
mgmtsts="$(echo "$mdmdump" | /usr/bin/awk '/^Management status: {/{flag=1;next}/^}$/{flag=0}flag && $0 !~ /= \{length = /')"


if [ -z "$agntrsp" ] || [ -z "$dmonrsp" ] || [ -z "$mgmtsts" ]
then
	echo "This device does not appear to be MDM enrolled (no management response found). Exiting..."; exit 1
fi


agntrsp="$(printf '{\n%s\n}\n' "$agntrsp" | /usr/bin/plutil -convert json -o - -)"
dmonrsp="$(printf '{\n%s\n}\n' "$dmonrsp" | /usr/bin/plutil -convert json -o - -)"
mgmtsts="$(printf '{\n%s\n}\n' "$mgmtsts" | /usr/bin/plutil -convert json -o - -)"
mdmjson="$(/usr/bin/jq --argjson a "$agntrsp" --argjson d "$dmonrsp" --argjson m "$mgmtsts" -n '{"Agent response":$a,"Daemon response":$d,"Management status":$m}')"
mngduid="$(echo "$mdmjson" | /usr/bin/jq -c '."Daemon response".QueryResponses.ActiveManagedUsers // []')"
mngdusr="$(/usr/bin/dscl . -list /Users GeneratedUID | /usr/bin/jq -R -s -r --argjson managed "$mngduid" '
	split("\n")
	| map(select(length > 0) | capture("^(?<name>\\S+)\\s+(?<guid>\\S+)$"))
	| map(select(.guid as $g | $managed | index($g)))
	| map(.name)
	| join(" ")
')"


if [ -n "$mngdusr" ]
then
	echo "MDM Managed users: $mngdusr"
else
	echo "No MDM managed users."
fi



# dumpALBState
# dumpAssociatedDomains
# dumpDEPState
# dumpEvents
# dumpManagementStatus
# dumpOrganizationInfo
# dumpPlugInKitSettings
# dumpPlugIns
# dumpSCEPVars
# dumpSessions
# dumpStore
# QueryCertificates
# QueryInstalledApplicationList
# QueryInstalledApps
# QueryInstalledProfiles
# QueryProfileList
# QuerySecurityInfo
