#!/bin/bash

# Build & sign a macOS distribution installer from a payload folder using pkgbuild
# & productbuild's --sign flags.

# Usage:
#   ./build.distribution.pkg.sh </path/to/folder/> </path/to/scripts/> <package identifier> <package version> <"Developer ID Installer: Name (TEAMID)"> <path/to/output.pkg> </path/to/distribution.xml> <notarization-profile> <wrap-in-dmg> <"Developer ID Application: Name (TEAMID)">

# Workflow:
#   app-signing > pkgbuild with package-signing > synthesize distribution.xml (if needed) >
#   productbuild with package-signing > verify > notarization (optional) > wrap in .dmg (optional).

# Options can be supplied on the CLI when executing or populated in the variables at the
# top of the script.

# scripts is optional -- leave blank to build the component package without a --scripts payload.

# To use this script Apple Developer identities must already be installed in your keychain.
# To install identity certs go to Xcode.app -> Settings -> Accounts -> Manage Certificates,
# or download from developer.apple.com - app signing & package signing are required.

# The command `/usr/bin/security find-identity -v -p basic` can confirm if Apple Developer
# identities are installed.

# Using a distribution.xml file is optional. If omitted, the script prompts for a path
# (blank defaults to 'distribution.xml' in the current directory). If the file doesn't
# exist yet, one is synthesized & consumed for the build.

# notarization-profile is a name previously stored via the following command:
#   xcrun notarytool store-credentials <profile-name> --apple-id ... --team-id ... --password ...

# Any non-blank value wraps the built package in a .dmg. 

# app-cert / installer-cert: which identity to use when more than one Developer ID
# Application / Installer cert is in the keychain. Required if the keychain has more than
# one of either.


# user variables
path_to_folder=''
path_to_scripts=''
package_identifier=''
package_version=''
developer_id=''
path_to_pkg=''
path_to_distribution_xml=''
notarization_profile=''
wrap_in_dmg=''
app_cert=''


###############################
##### DO NOT MODIFY BELOW #####
###############################


# errors
errnrot(){ printf '\nerror: missing root-dir\n' >&2; }
errnidt(){ printf '\nerror: missing identifier\n' >&2; }
errnver(){ printf '\nerror: missing version\n' >&2; }
errnout(){ printf '\nerror: missing output-name\n' >&2; }
errapcr(){ printf '\nerror: app-cert "%s" not found in keychain.\n' "$appcrt" >&2; }
errincr(){ printf '\nerror: installer-cert "%s" not found in keychain.\n' "$inscrt" >&2; }
errcert(){ printf '\nerror: both a Developer ID Application & a Developer ID Installer certificate are required in the keychain.\n' >&2; }
errcsgn(){ printf '\nerror: codesigning "%s" failed.\n' "$app" >&2; }
errpkgb(){ printf '\nerror: pkgbuild failed.\n' >&2; }
errsynt(){ printf '\nerror: synthesizing %s failed.\n' "$distxm" >&2; }
errprod(){ printf '\nerror: productbuild failed.\n' >&2; }
errntry(){ printf '\nerror: notarization failed.\n' >&2; }


# functions & data
resolve_cert(){
	local filter="$1" policy="$2" override="$3"
	local list teams
	if [[ -n "$override" ]]
	then
		/usr/bin/security find-identity -v -p "$policy" | /usr/bin/grep -q "$override" || return 1
		rsltid="$override"
		return 0
	fi
	list="$(/usr/bin/security find-identity -v -p basic | /usr/bin/grep "$filter")"
	teams="$(echo "$list" | /usr/bin/sed -E 's/.*\(([^)]+)\)".*/\1/' | /usr/bin/sort -u)"
	if [[ "$(echo "$teams" | /usr/bin/grep -c .)" -gt 1 ]]
	then
		echo "multiple $filter certificates found, for different teams:"
		echo "$list"
		read -r -p "SHA-1 of the certificate to use: " rsltid
	else
		rsltid="$(echo "$list" | /usr/bin/awk '{print $2}' | /usr/bin/head -1)"
	fi
}

rootdr="${1:-$path_to_folder}"
scptdr="${2:-$path_to_scripts}"
idntfr="${3:-$package_identifier}"
vrsion="${4:-$package_version}"
inscrt="${5:-$developer_id}"
outnam="${6:-$path_to_pkg}"
distxm="${7:-$path_to_distribution_xml}"
notprf="${8:-$notarization_profile}"
wrpdmg="${9:-$wrap_in_dmg}"
appcrt="${10:-$app_cert}"


# error handling
if [[ -z "$rootdr" ]]; then errnrot; exit 1; fi
if [[ -z "$idntfr" ]]; then errnidt; exit 1; fi
if [[ -z "$vrsion" ]]; then errnver; exit 1; fi
if [[ -z "$outnam" ]]; then errnout; exit 1; fi


# match certs by SHA-1 fingerprint & team ID
if ! resolve_cert 'Developer ID Application' codesigning "$appcrt"
then
	errapcr; exit 1
fi
appsig="$rsltid"

if ! resolve_cert 'Developer ID Installer' basic "$inscrt"
then
	errincr; exit 1
fi
signid="$rsltid"

if [[ -z "$appsig" || -z "$signid" ]]
then
	errcert; exit 1
fi


# distribution.xml path
if [[ -z "$distxm" ]]
then
	read -r -p "Path to distribution.xml (blank to generate one): " distxm
	[[ -z "$distxm" ]] && distxm='distribution.xml'
fi
cmppkg='component.pkg'
finpkg="$outnam.pkg"


# payload
while IFS= read -r -d '' app
do
	echo "codesigning $app..."
	if ! /usr/bin/codesign -s "$appsig" --timestamp -f "$app"
	then
		errcsgn; exit 1
	fi
done < <(/usr/bin/find "$rootdr" -name '*.app' -print0)


# component package
echo "building component package..."
pkgargs=(--identifier "$idntfr" --version "$vrsion" --root "$rootdr" --sign "$signid")
if [[ -n "$scptdr" ]]
then
	pkgargs+=(--scripts "$scptdr")
fi

if ! /usr/bin/pkgbuild "${pkgargs[@]}" "$cmppkg"
then
	errpkgb; exit 1
fi


# synthesize distribution.xml
if [[ ! -e "$distxm" ]]
then
	echo "synthesizing $distxm..."
	/usr/bin/productbuild --synthesize --package "$cmppkg" "$distxm" || { errsynt; exit 1; }
fi


# distribution package
echo "building distribution package..."
if ! /usr/bin/productbuild --distribution "$distxm" --package-path . --sign "$signid" "$finpkg"
then
	errprod; exit 1
fi


# verify
echo "verifying..."
/usr/sbin/pkgutil --check-signature "$finpkg"
/usr/sbin/spctl -a -v --type install "$finpkg"


# notarization
if [[ -n "$notprf" ]]
then
	echo "submitting for notarization..."
	if /usr/bin/xcrun notarytool submit "$finpkg" --keychain-profile "$notprf" --wait
	then
		/usr/bin/xcrun stapler staple "$finpkg"
	else
		errntry; exit 1
	fi
fi


# disk image
if [[ -n "$wrpdmg" ]]
then
	echo "wrapping in a disk image..."
	dmgdir="$(/usr/bin/mktemp -d)"
	/bin/cp "$finpkg" "$dmgdir/"
	/usr/sbin/diskutil image create from --volumeName "$outnam" "$dmgdir" "$outnam.dmg"
	/bin/rm -rf "$dmgdir"
fi
