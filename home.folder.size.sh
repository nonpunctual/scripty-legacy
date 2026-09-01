#!/bin/sh

# set -x
# trap read debug

# macOS version check

if [ "$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}')" -ge 12 ]
then
	byteblk='--si'
else
	byteblk='-h'
fi

# collect home folder size (collects size of dot files but excludes from display)

crntusr="$(/usr/bin/stat -f %Su /dev/console)" 
dscldir="$(/usr/bin/dscl -plist . read /Users/"$crntusr" NFSHomeDirectory)"
homedir="$(/usr/libexec/PlistBuddy -c "print dsAttrTypeStandard\:NFSHomeDirectory:0" /dev/stdin <<< "$dscldir")"
homesiz="$(/usr/bin/du -d 1 "$byteblk" "$homedir" 2>&1 | /usr/bin/awk '!/\/\./&&!/du: /{print}' | /usr/bin/sort -k 2)"

echo "<result>$homesiz</result>"