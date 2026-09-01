#!/bin/bash

# set -x
# trap read debug

# macOS.block.app.sh @2024 Fleet Device Management


# check for root execution
if [ "$EUID" != 0 ]
then
	printf "\nThis script must be executed by the root user. Exiting...\n"; exit
fi


#####################################
### variables: populate as needed ###
#####################################

# The text that appears on the title bar of the AppleScript dialog window
apscttl='Migration Assistant Blocked'

# The text that appears in the AppleScript dialog window
apsctxt='Migration Assistant is blocked on this computer. Please contact your administrator for help.'

# The name of the app to block as it appears in Finder
blckapp='Migration Assistant'

# The 'identifier' for the 'block', e.g., blk.migr.asst
prcidnt='blk.migr.asst'

###########################
### DO NOT MODIFY BELOW ###
###########################


# paths
plstpth="/Library/LaunchDaemons/com.$prcidnt.plist"
scptpth="/opt/$prcidnt.sh"


# write out blocking script
/bin/cat << EOF > "$scptpth"
#!/bin/sh

if /usr/bin/pgrep -ail "$blckapp"
then
    /usr/bin/pkill -ail "$blckapp"
    /usr/bin/osascript -e "display dialog \"${apsctxt}\" buttons {\"OK\"} default button 1 with title \"${apscttl}\" with icon file \"System:Library:CoreServices:CoreTypes.bundle:Contents:Resources:AlertStopIcon.icns\""
fi
EOF
/bin/chmod 755 "$scptpth"
/usr/sbin/chown 0:0 "$scptpth"


# write out launch daemon
/bin/cat << EOF > "$plstpth"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
      <string>$prcidnt</string>
    <key>ProgramArguments</key>
      <array>
        <string>/bin/sh</string>
        <string>$scptpth</string>
      </array>
    <key>RunAtLoad</key>
      <true/>
    <key>KeepAlive</key>
      <true/>
  </dict>
</plist>
EOF
/bin/chmod 644 "$plstpth"
/usr/sbin/chown 0:0 "$plstpth"
/usr/bin/plutil -convert binary1 "$plstpth"


# start launch daemon
/bin/launchctl bootstrap system "$plstpth"
