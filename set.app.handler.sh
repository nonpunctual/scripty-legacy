#!/bin/sh

# Sets permissions/ownership on an already-installed swda (SwiftDefaultApps CLI) binary, then uses it to set Microsoft Outlook as the default handler for .ics UTIs (normally Apple Calendar).
# https://github.com/Lord-Kamina/SwiftDefaultApps/releases

/bin/chmod 755 '/usr/local/bin/swda'
/usr/bin/xattr -c '/usr/local/bin/swda'
/usr/sbin/chown 0:0 '/usr/local/bin/swda'

# sets Handler (application) for .ics files (which defaults to Apple Calendar) to Microsoft Outlook
/usr/local/bin/swda setHandler --app '/Applications/Microsoft Outlook.app' --UTI 'com.apple.ical.ics'; /bin/sleep 1
/usr/local/bin/swda setHandler --app '/Applications/Microsoft Outlook.app' --UTI 'com.apple.ical.ics.event'; /bin/sleep 1
/usr/local/bin/swda setHandler --app '/Applications/Microsoft Outlook.app' --UTI 'com.apple.ical.ics.todo'; /bin/sleep 1

# check settings
/usr/local/bin/swda getHandler --UTI 'com.apple.ical.ics'; /bin/sleep 1
/usr/local/bin/swda getHandler --UTI 'com.apple.ical.ics.event'; /bin/sleep 1
/usr/local/bin/swda getHandler --UTI 'com.apple.ical.ics.todo'; /bin/sleep 1
