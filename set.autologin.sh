#!/bin/bash



# WARNING: This is a crazy thing to do. Enabling autologin is genrally considered bad.

# It is specifcally recommended to be turned off in almost all security benchmarks like
# CIS. You should not enable it unless you have to & the conditions for the computer with
# autologin enabled are safe. "Safe" in this context is subjective, but, consider examples
# like the compuuter is: 
# - locked in a lab with badged access
# - installed in a server room or rack with badged access
# - in use as a "kiosk" that is mounted in a way that's difficult to access
# - maybe not on a network

# This script is meant to show a technique & is intended to be used as a postinstall script
# in a .pkg installer as part of a workflow. It can be run on a freshly erased Mac or one that
# you don't mind getting hosed...

# The autologin user account name & password are randomly generated. A Launch Daemon is 
# installed to remove all accounts other than the autologin account after reboot

# In order to erase a Mac using "Erase All Contents & Settings" an admin passowrd is 
# required. Take note of the user account name & password for the created autologin user
# when this script completes & store them safely.



# variables & functions


genpswd="$(/usr/bin/openssl rand -base64 24)"


rootfnc(){
if [ "$EUID" != 0 ]
then
	printf "\nThis script must be executed as the root user. Exiting...\n"; exit 1
fi
}


chkfnc(){
curusr="$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null)"
}


namefnc(){
while IFS= read -r wrd
do
	wordarr+=("$wrd")
done < <(/usr/bin/grep -E '^[a-z]{4,8}$' /usr/share/dict/words)

rndword="${wordarr[$((RANDOM % ${#wordarr[@]}))]}"
rnduuid="$(/usr/bin/uuidgen | /usr/bin/awk -F '-' '{print $1}' | /usr/bin/tr '[:upper:]' '[:lower:]')"
trgtusr="${rndword}${rnduuid}"
}


userfnc(){
if /usr/bin/dscl . -list /Users | /usr/bin/grep -qx "$trgtusr"
then
	printf "\nUser account '%s' already exists. Skipping creation...\n" "$trgtusr"
else
	/usr/sbin/sysadminctl -addUser "$trgtusr" -fullName "$trgtusr" -password "$genpswd" -admin
fi
}


autofnc(){
/usr/sbin/sysadminctl -autologin set -userName "$trgtusr" -password "$genpswd" -adminUser "$trgtusr" -adminPassword "$genpswd"
}


acctfnc(){
plstpth="/Library/LaunchDaemons/com.rmusers.plist"
scptpth="/opt/rmusers.sh"

printf '#!/bin/sh\n\nkeepusr="%s"\n\n' "$trgtusr" > "$scptpth"

/bin/cat << 'EOF' >> "$scptpth"
/usr/bin/dscl . -list /Users | while read -r usrnam
do
	usrshl="$(/usr/bin/dscl . -read "/Users/$usrnam" UserShell 2>/dev/null | /usr/bin/awk '{print $2}')"
	usrpwd="$(/usr/bin/dscl . -read "/Users/$usrnam" Password 2>/dev/null | /usr/bin/awk '{print $2}')"

	if [ "$usrshl" != "/usr/bin/false" ] && [ "$usrpwd" = "********" ] && [ "$usrnam" != "$keepusr" ] && [ "$usrnam" != "root" ] && [ "$usrnam" != "nobody" ] && [ "$usrnam" != "daemon" ]
	then
		usrhome="$(/usr/bin/dscl . -read "/Users/$usrnam" NFSHomeDirectory | /usr/bin/awk '{print $2}')"
		/usr/sbin/dseditgroup -o edit -d "$usrnam" -t user admin
		/usr/bin/dscl . -delete "/Users/$usrnam"

		if /usr/bin/dscl . -list /Users | /usr/bin/grep -qx "$usrnam"
		then
			/usr/sbin/dseditgroup -o edit -d "$usrnam" -t user admin
			/usr/bin/dscl . -delete "/Users/$usrnam"
		fi

		if /usr/bin/dscl . -list /Users | /usr/bin/grep -qx "$usrnam"
		then
			printf '%s still present after delete retry\n' "$usrnam" >> /var/log/rmusers.log
		else
			[ -n "$usrhome" ] && /bin/rm -rf "$usrhome"
		fi
	fi
done

/bin/launchctl bootout system/rmusers; /bin/sleep 5
/bin/rm -f /Library/LaunchDaemons/com.rmusers.plist /opt/rmusers.sh
EOF

/bin/chmod 755 "$scptpth"
/usr/sbin/chown 0:0 "$scptpth"

/bin/cat << EOF > "$plstpth"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
      <string>rmusers</string>
    <key>ProgramArguments</key>
      <array>
        <string>/bin/sh</string>
        <string>$scptpth</string>
      </array>
    <key>RunAtLoad</key>
      <true/>
  </dict>
</plist>
EOF

/bin/chmod 644 "$plstpth"
/usr/sbin/chown 0:0 "$plstpth"
/usr/bin/plutil -convert binary1 "$plstpth"
}


# operations

rootfnc
chkfnc

if [ -n "$curusr" ]
then
	printf "\nAutologin is already configured for '%s'. Skipping account creation...\n" "$curusr"
	trgtusr="$curusr"
else
	namefnc
	userfnc
	autofnc
	printf "\nAutologin account created. Record these credentials and store them safely -- they are not saved anywhere else:\n\nusername: %s\npassword: %s\n" "$trgtusr" "$genpswd"
fi

/usr/bin/defaults write /Library/Preferences/.GlobalPreferences MultipleSessionEnabled -bool false
acctfnc
/usr/sbin/sysadminctl -autologin status
/sbin/reboot
