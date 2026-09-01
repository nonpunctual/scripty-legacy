#!/bin/bash

# Build & sign a macOS component .pkg from a payload folder using pkgbuild's --sign flag.

# Usage:
#   ./build.component.pkg.sh </path/to/folder> </path/to/scripts/> <package identifier> <package version> <"Developer ID Installer: Name (TEAMID)"> <path/to/.pkg>

# Options can be supplied on the CLI when executing or populated in the variables at the
# top of the script.

# To use this script Apple Developer identities must already be installed in your keychain.
# To install identity certs go to Xcode.app -> Settings -> Accounts -> Manage Certificates,
# or download from developer.apple.com

# The command `/usr/bin/security find-identity -v -p basic` can confirm if Apple Developer
# identities are installed.

# output.pkg defaults to "<folder-basename>.pkg" in the current directory.
# scripts is optional -- leave blank to build without a --scripts payload.


# user variables
path_to_folder=''
path_to_scripts=''
package_identifier=''
package_version=''
developer_id=''
path_to_pkg=''


###############################
##### DO NOT MODIFY BELOW #####
###############################


# errors
errpath(){ printf '\nerror: missing path to folder\n' >&2; }
erridnt(){ printf '\nerror: missing package identifier\n' >&2; }
errvers(){ printf '\nerror: missing package version\n' >&2; }
errsign(){ printf '\nerror: missing signing identity\n' >&2; }
errfldr(){ printf "\nerror: '%s' is not a folder\n" "$pkgfldr" >&2; }
errdvlp(){ printf '\nerror: signing identity not found in keychain: %s\n\nAvailable identities:\n' "$pkgsign" >&2; }
errpkgb(){ printf '\nerror: pkgbuild failed\n' >&2; }


# variables
pkgfldr="${1:-$path_to_folder}"
pkgscpt="${2:-$path_to_scripts}"
pkgidnt="${3:-$package_identifier}"
pkgvers="${4:-$package_version}"
pkgsign="${5:-$developer_id}"
pkgpath="${6:-$path_to_pkg}"


# error handling
if [ -z "$pkgfldr" ]; then errpath; exit 1; fi
if [ -z "$pkgidnt" ]; then erridnt; exit 1; fi
if [ -z "$pkgvers" ]; then errvers; exit 1; fi
if [ -z "$pkgsign" ]; then errsign; exit 1; fi
if [ ! -d "$pkgfldr" ]; then errfldr; exit 1; fi
if ! /usr/bin/security find-identity -v -p basic 2>/dev/null | /usr/bin/grep -qF "$pkgsign"
then
    errdvlp; /usr/bin/security find-identity -v -p basic >&2; exit 1
fi


# operations
if [ -z "$pkgpath" ]
then
    pkgbase="$(/usr/bin/basename "$pkgfldr")"
    pkgpath="$(/bin/pwd)/$pkgbase.pkg"
fi

pkgargs=(--root "$pkgfldr" --identifier "$pkgidnt" --version "$pkgvers" --sign "$pkgsign" --install-location "/")
if [ -n "$pkgscpt" ]
then
    pkgargs+=(--scripts "$pkgscpt")
fi

if ! /usr/bin/pkgbuild "${pkgargs[@]}" "$pkgpath"
then
    errpkgb; exit 1
fi

printf 'Signed: %s\n' "$pkgpath"
/usr/sbin/pkgutil --check-signature "$pkgpath"
