#!/bin/bash


# set -x
# trap read debug


# check for root execution
if [ "$EUID" != 0 ]
then
	printf "\nThis script must be executed by the root user. Exiting...\n"; exit
fi


# variables
usracct="$1"
newpict="$2"
tmpfldr="$(/usr/bin/mktemp)"


# delete current user account images & populate new image
/usr/bin/dscl . delete /Users/"$usracct" JPEGPhoto
/usr/bin/dscl . delete /Users/"$usracct" Picture
printf "0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto\n%s:%s" "$usracct" "$newpict" > "$tmpfldr"
/usr/bin/dsimport "$tmpfldr" /Local/Default M
/bin/rm -f -r "$tmpfldr"
