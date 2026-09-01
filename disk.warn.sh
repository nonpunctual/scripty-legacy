#!/bin/bash
#shellcheck disable=SC2154



# disk.warn.sh @2026 Fleet Device Management
# Brock Walters (brock@fleetdm.com)



# check for root execution
if [ "$EUID" != 0 ]
then
	printf "\nThis script must be executed by the root user. Exiting...\n"; exit
fi



# paths
plstpth="/Library/LaunchDaemons/com.disk.warn.plist"
scptpth="/opt/disk.warn.sh"



# write out script if not found
if [ ! -f "$scptpth" ]
then

/bin/cat << 'EOF' > "$scptpth"
#!/bin/sh

dskusd="$(/usr/bin/osascript -l 'JavaScript' -e "var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, $.NSURLVolumeAvailableCapacityForImportantUsageKey, null); Math.round(freeSpaceBytesRef[0].js / 1000000000)")"
dsksiz="$(/usr/libexec/PlistBuddy -c 'print AllDisksAndPartitions:0:Size' /dev/stdin <<< "$(/usr/sbin/diskutil list -plist disk0)")"
dskttl="$((dsksiz/1000000000))"
dskpct=$(( dskusd * 100 / dskttl ))

if [ "$dskpct" -lt 10 ]
then
	  /usr/bin/osascript -e "display dialog \"Your system disk has 10% or less capacity available.\" buttons {\"OK\"} default button 1 with title \"Disk Space Warning\" with icon file \"System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns\""
fi
EOF

/bin/chmod 755 "$scptpth"
/usr/sbin/chown 0:0 "$scptpth"

fi



# write out launch daemon if not found
if [ ! -f "$plstpth" ]
then

/bin/cat << EOF > "$plstpth"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
      <string>disk.warn</string>
    <key>ProgramArguments</key>
      <array>
        <string>/bin/sh</string>
        <string>$scptpth</string>
      </array>
    <key>RunAtLoad</key>
      <true/>
	  <key>StartInterval</key>
	  <integer>60</integer>
  </dict>
</plist>
EOF

/bin/chmod 644 "$plstpth"
/usr/sbin/chown 0:0 "$plstpth"
/usr/bin/plutil -convert binary1 "$plstpth"

# start launch daemon
/bin/launchctl bootstrap system "$plstpth"

fi
