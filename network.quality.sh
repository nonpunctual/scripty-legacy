#!/bin/bash


# set -x
# trap read debug


filpth='/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources'
tsttyp=$(/usr/bin/osascript -e "choose from list {\"Download + Upload Speed\", \"Video Conferencing\"} with title \"Network Quality Test\" with prompt \"Please select test type to begin:\"")

case "$tsttyp" in
'false'                       ) exit ;;
    'Download + Upload Speed' ) icnsnm='GenericNetworkIcon' option='-sv' ;;
    'Video Conferencing'      ) icnsnm='GroupIcon' option='-v' ;;
esac

sumpth="$(/usr/bin/mktemp /private/tmp/network.quality.summary.XXXXXX)"
trap 'rm -f "$sumpth"' EXIT

/usr/bin/osascript -e "display dialog \"Test in progress...\n\" buttons {\"Cancel\"} with icon POSIX file \"$filpth/$icnsnm.icns\" with Title \"Network Quality Test - $tsttyp\"" &
prgpid=$!
/usr/bin/networkquality "$option" | /usr/bin/sed '/SUMMARY/d' > "$sumpth" &

while true
do
    if [ -n "$(/bin/cat "$sumpth")" ]
    then
        break
    fi
    if /bin/kill -s 0 "$prgpid"
    then
        >&2 echo "waiting for networkquality..."; /bin/sleep 3
    else
        exit
    fi
done

sumtxt="$(/bin/cat "$sumpth")"
>&2 echo "$sumtxt"
/usr/bin/osascript -e "display dialog \"$sumtxt\" buttons {\"Ok\"} default button 1 with icon POSIX file \"$filpth/$icnsnm.icns\" with Title \"Network Quality Test - $tsttyp\""
/bin/kill -9 "$prgpid"