#!/bin/bash


#   "script": "set.user.name",
#   "org": "@2025 Fleet",
#   "author": "brock@fleetdm.com",
#   "modified": "2025-06-13",
#   "version": 5


# check for root execution
if [ "$EUID" != 0 ]
then
	printf "\nThis script must be executed by the root user. Exiting...\n"; exit
fi


# collect hardware info
hwmdlnm="$(/usr/libexec/PlistBuddy -c 'print 0:product-name' /dev/stdin <<< "$(/usr/sbin/ioreg -ar -k product-name)")"
hwsocnm="$(/usr/libexec/PlistBuddy -c 'print 0:product-soc-name' /dev/stdin <<< "$(/usr/sbin/ioreg -ar -k product-name)" | /usr/bin/awk '{print $2}')"


# collect & modify 501 user info with the assumption that the short name format is firstname.lastname
rcrdnam="$(/usr/bin/id -u -n 501)"
realnam="$(/usr/libexec/PlistBuddy -c 'print dsAttrTypeStandard\:RealName:0' /dev/stdin <<< "$(/usr/bin/dscl -plist . -read /Users/"$rcrdnam" RealName)")"
usrnam1="$(echo "$rcrdnam" | /usr/bin/awk -F '.' '{print $1}')"
usrnam2="$(echo "$rcrdnam" | /usr/bin/awk -F '.' '{print $2}')"
capnam1="$(/usr/bin/tr '[:lower:]' '[:upper:]' <<< "${usrnam1:0:1}")${usrnam1:1}"
capnam2="$(/usr/bin/tr '[:lower:]' '[:upper:]' <<< "${usrnam2:0:1}")${usrnam2:1}"


# update 501 user RealName, ComputerName, HostName, LocalHostName
/usr/bin/dscl . -change /Users/"$rcrdnam" RealName "$realnam" "$capnam1 $capnam2" 
/usr/sbin/scutil --set ComputerName "$rcrdnam $hwsocnm $hwmdlnm"
/usr/sbin/scutil --set HostName "$rcrdnam"
/usr/sbin/scutil --set LocalHostName "$(echo "$rcrdnam" | /usr/bin/sed 's/\.//')"
