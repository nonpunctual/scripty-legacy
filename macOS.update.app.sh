#!/bin/zsh

# Removes an installed app if its version is older than a given minimum, using zsh's `is-at-least` instead of regex version comparisons. Must be run as root.


# notes:
# $4 Script Parameter in Jamf must be an application bundle id, e.g., com.apple.dt.Xcode
# $5 Script Parameter in Jamf must be an application bundle name, e.g., Xcode.app
# $6 Script Parameter in Jamf must be an application short version string, e.g., 14.2
# $7 Script Parameter in Jamf toggles a test mode. If populated with the string "test" the script will perform a "dry run" without removing files.


# variables (only populate these if Jamf Script Parameters are not used)
varbndl=''
varname=''
varvers=''


###############################
##### DO NOT MODIFY BELOW #####
###############################


# data
appbndl="${4:-$varbndl}"
appname="${5:-$varname}"
appvers="${6:-$varvers}"
tstmode="$7"

IFS=$'\n'

arrdata=($(/usr/bin/mdfind -0 "kMDItemCFBundleIdentifier = $appbndl" | /usr/bin/xargs -0 /usr/bin/mdls -name 'kMDItemVersion' -name 'kMDItemPath' | /usr/bin/sed 's/kMDItemPath = //g;s/kMDItemVersion = //g'))


# functions
appvr_ck(){ >&2 printf "\nChecking %s versions...\n" "$appname" ; }
appvr_no(){ >&2 printf "\nNo %s found. Exiting...\n" "$appname" ; }
appvr_ok(){ >&2 printf "\nFound %s\nversion = %s\nOk. Leaving %s in place...\n" "${arrdata[i-1]}" "${arrdata[i]}" "$appname" ; }
appvr_rm(){
    appkill="$(echo "${arrdata[i-1]}" | /usr/bin/sed 's/"//g')"
    >&2 printf "\nFound %s\nversion = %s\nInsecure version. Deleting %s...\n" "$appkill" "${arrdata[i]}" "$appkill"; /bin/rm -f -r "$appkill"
    >&2 printf "\nValidating deleted path: %s\n" "$appkill"; /bin/ls -ls "$appkill"
    exit 0
}
appvr_tm(){
    >&2 printf "\nFound %s\nversion = %s\nInsecure version. Deleting %s\n" "${arrdata[i-1]}" "${arrdata[i]}" "${arrdata[i-1]}"
    >&2 printf "\n!!! TEST MODE !!! Disabling test mode will remove: %s\n" "${arrdata[i-1]}"
}
autoload is-at-least
not_root(){ >&2 printf "\nThis script must be executed as the root user. Exiting...\n" ; }


# operations
if [ "$EUID" != 0 ]
then
    not_root; exit
fi

if [ -z "${arrdata[*]}" ]
then
    appvr_no; exit
fi

appvr_ck
for ((i=2;i<=${#arrdata[@]};i+=2))
{
    if is-at-least "$appvers" "${arrdata[i]}"
    then
        appvr_ok; continue
    else
        case "$tstmode" in
            'test' ) appvr_tm ;;
                 * ) appvr_rm ;;
        esac
    fi
}
