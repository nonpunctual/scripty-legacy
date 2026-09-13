#!/bin/bash

# Build & sign a macOS .pkg via pkgbuild/productbuild's --sign flags. Mode is required
# and selects what gets built:
#   --component   / -C   a standalone component .pkg (pkgbuild only)
#   --distribution / -D  a full signed, optionally notarized (and optionally
#                        .dmg-wrapped) distribution installer (pkgbuild + productbuild)

# Usage:
#   ./build.pkg.sh (--component|-C) </path/to/folder> </path/to/scripts/> <package identifier> <package version> <"Developer ID Installer: Name (TEAMID)"> <path/to/output.pkg> </path/to/component-plist>
#   ./build.pkg.sh (--distribution|-D) </path/to/distribution.xml> </path/to/folder/> </path/to/resources/> </path/to/scripts/> <path/to/output-name> <package identifier> <package version> <"Developer ID Installer: Name (TEAMID)"> <"Developer ID Application: Name (TEAMID)"> <notarization-profile> <wrap-in-dmg> </path/to/component-plist> </path/to/entitlements.plist>

# The mode flag must come first. Everything after it is positional, in the order shown
# above for that mode -- the two modes do NOT share one positional order.

# Options can be supplied on the CLI when executing or populated in the variables at the
# top of the script (mode itself is CLI-only; there's no default-mode variable).

# To use this script Apple Developer identities must already be installed in your keychain.
# To install identity certs go to Xcode.app -> Settings -> Accounts -> Manage Certificates,
# or download from developer.apple.com - --distribution mode needs both a Developer ID
# Application & a Developer ID Installer certificate; --component mode needs only the
# Developer ID Installer certificate.

# The command `/usr/bin/security find-identity -v -p basic` can confirm if Apple Developer
# identities are installed.

# scripts is optional -- leave blank to build without a --scripts payload.

# resources is optional (--distribution only) -- leave blank to build without a
# --resources payload (no welcome/readme/license/conclusion text panes will be shown
# by Installer.app).

# component-plist is optional -- leave blank to let pkgbuild infer bundle relocation/
# versioning behavior on its own. Generate one via `pkgbuild --analyze --root <folder>`
# and edit as needed (e.g. set BundleIsRelocatable to false for a bundle that must
# always install to a fixed path, regardless of any same-identifier bundle Launch
# Services has registered elsewhere on disk).

# output.pkg (--component) defaults to "<folder-basename>.pkg" in the current directory.
# output-name (--distribution) is used as "<output-name>.pkg", written to the current
# directory; component.pkg is also written to the current directory as an intermediate.

# Using a distribution.xml file is optional (--distribution only). If omitted, the
# script prompts for a path (blank defaults to 'distribution.xml' in the current
# directory). If the file doesn't exist yet, one is synthesized & consumed for the build.

# notarization-profile (--distribution only) is a name previously stored via:
#   xcrun notarytool store-credentials <profile-name> --apple-id ... --team-id ... --password ...

# wrap-in-dmg (--distribution only): any non-blank value wraps the built package in a .dmg.

# entitlements.plist (--distribution only) is optional -- leave blank to codesign each
# .app found in the folder without --entitlements (the prior default). When set, every
# .app codesigned during packaging gets --entitlements <path>. Needed for anything an
# app's own build step already signed with entitlements (e.g. Location Services), since
# this script's own re-sign otherwise silently drops them.

# app-cert / developer-id (--distribution only): which identity to use when more than
# one Developer ID Application / Installer certificate is in the keychain. Required if
# the keychain has more than one of either.


# user variables
path_to_component_plist=''
path_to_distribution_xml=''
path_to_entitlements=''
path_to_folder=''
path_to_resources=''
path_to_scripts=''
path_to_pkg=''
package_identifier=''
package_version=''
developer_id=''
app_cert=''
notarization_profile=''
wrap_in_dmg=''


###############################
##### DO NOT MODIFY BELOW #####
###############################


# errors
errmode(){ printf '\nerror: first argument must be --component/-C or --distribution/-D\n' >&2; }
errpath(){ printf '\nerror: missing path to folder\n' >&2; }
erridnt(){ printf '\nerror: missing package identifier\n' >&2; }
errvers(){ printf '\nerror: missing package version\n' >&2; }
errsign(){ printf '\nerror: missing signing identity\n' >&2; }
errfldr(){ printf "\nerror: '%s' is not a folder\n" "$fldr" >&2; }
errdvlp(){ printf '\nerror: signing identity not found in keychain: %s\n\nAvailable identities:\n' "$dvid" >&2; }
errapcr(){ printf '\nerror: app-cert "%s" not found in keychain.\n' "$appc" >&2; }
errincr(){ printf '\nerror: installer-cert "%s" not found in keychain.\n' "$dvid" >&2; }
errcert(){ printf '\nerror: both a Developer ID Application & a Developer ID Installer certificate are required in the keychain.\n' >&2; }
errcsgn(){ printf '\nerror: codesigning "%s" failed.\n' "$app" >&2; }
errpkgb(){ printf '\nerror: pkgbuild failed.\n' >&2; }
errsynt(){ printf '\nerror: synthesizing %s failed.\n' "$distx" >&2; }
errprod(){ printf '\nerror: productbuild failed.\n' >&2; }
errntry(){ printf '\nerror: notarization failed.\n' >&2; }


# functions
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


# mode
mode="$1"
if [[ "$mode" != "--component" && "$mode" != "-C" && "$mode" != "--distribution" && "$mode" != "-D" ]]
then
    errmode; exit 1
fi
shift


if [[ "$mode" == "--component" || "$mode" == "-C" ]]
then

    # component mode: variables
    fldr="${1:-$path_to_folder}"
    scpt="${2:-$path_to_scripts}"
    idnt="${3:-$package_identifier}"
    vers="${4:-$package_version}"
    dvid="${5:-$developer_id}"
    pkgp="${6:-$path_to_pkg}"
    cplt="${7:-$path_to_component_plist}"

    # component mode: error handling
    if [ -z "$fldr" ]; then errpath; exit 1; fi
    if [ -z "$idnt" ]; then erridnt; exit 1; fi
    if [ -z "$vers" ]; then errvers; exit 1; fi
    if [ -z "$dvid" ]; then errsign; exit 1; fi
    if [ ! -d "$fldr" ]; then errfldr; exit 1; fi
    if ! /usr/bin/security find-identity -v -p basic 2>/dev/null | /usr/bin/grep -qF "$dvid"
    then
        errdvlp; /usr/bin/security find-identity -v -p basic >&2; exit 1
    fi

    # component mode: build
    if [ -z "$pkgp" ]
    then
        pkgbase="$(/usr/bin/basename "$fldr")"
        pkgp="$(/bin/pwd)/$pkgbase.pkg"
    fi

    pkgargs=(--root "$fldr" --identifier "$idnt" --version "$vers" --sign "$dvid" --install-location "/")
    if [ -n "$scpt" ]
    then
        pkgargs+=(--scripts "$scpt")
    fi
    if [ -n "$cplt" ]
    then
        pkgargs+=(--component-plist "$cplt")
    fi

    if ! /usr/bin/pkgbuild "${pkgargs[@]}" "$pkgp"
    then
        errpkgb; exit 1
    fi

    printf 'Signed: %s\n' "$pkgp"
    /usr/sbin/pkgutil --check-signature "$pkgp"

else

    # distribution mode: variables
    distx="${1:-$path_to_distribution_xml}"
    fldr="${2:-$path_to_folder}"
    rsrc="${3:-$path_to_resources}"
    scpt="${4:-$path_to_scripts}"
    pkgp="${5:-$path_to_pkg}"
    idnt="${6:-$package_identifier}"
    vers="${7:-$package_version}"
    dvid="${8:-$developer_id}"
    appc="${9:-$app_cert}"
    notp="${10:-$notarization_profile}"
    dmg="${11:-$wrap_in_dmg}"
    cplt="${12:-$path_to_component_plist}"
    entc="${13:-$path_to_entitlements}"

    # distribution mode: error handling
    if [[ -z "$fldr" ]]; then errpath; exit 1; fi
    if [[ -z "$idnt" ]]; then erridnt; exit 1; fi
    if [[ -z "$vers" ]]; then errvers; exit 1; fi
    if [[ -z "$pkgp" ]]; then errpath; exit 1; fi

    # match certs by SHA-1 fingerprint & team ID
    if ! resolve_cert 'Developer ID Application' codesigning "$appc"
    then
        errapcr; exit 1
    fi
    appsig="$rsltid"

    if ! resolve_cert 'Developer ID Installer' basic "$dvid"
    then
        errincr; exit 1
    fi
    signid="$rsltid"

    if [[ -z "$appsig" || -z "$signid" ]]
    then
        errcert; exit 1
    fi

    # distribution.xml path
    if [[ -z "$distx" ]]
    then
        read -r -p "Path to distribution.xml (blank to generate one): " distx
        [[ -z "$distx" ]] && distx='distribution.xml'
    fi
    cmppkg='component.pkg'
    finpkg="$pkgp.pkg"

    # app signing
    while IFS= read -r -d '' app
    do
        echo "codesigning $app..."
        csargs=(-s "$appsig" --timestamp --options runtime -f)
        if [[ -n "$entc" ]]
        then
            csargs+=(--entitlements "$entc")
        fi
        if ! /usr/bin/codesign "${csargs[@]}" "$app"
        then
            errcsgn; exit 1
        fi
    done < <(/usr/bin/find "$fldr" -name '*.app' -print0)

    # component package
    echo "building component package..."
    pkgargs=(--identifier "$idnt" --version "$vers" --root "$fldr" --sign "$signid")
    if [[ -n "$scpt" ]]
    then
        pkgargs+=(--scripts "$scpt")
    fi
    if [[ -n "$cplt" ]]
    then
        pkgargs+=(--component-plist "$cplt")
    fi

    if ! /usr/bin/pkgbuild "${pkgargs[@]}" "$cmppkg"
    then
        errpkgb; exit 1
    fi

    # synthesize distribution.xml
    if [[ ! -e "$distx" ]]
    then
        echo "synthesizing $distx..."
        /usr/bin/productbuild --synthesize --package "$cmppkg" "$distx" || { errsynt; exit 1; }
    fi

    # distribution package
    echo "building distribution package..."
    prodargs=(--distribution "$distx" --package-path . --sign "$signid")
    if [[ -n "$rsrc" ]]
    then
        prodargs+=(--resources "$rsrc")
    fi

    if ! /usr/bin/productbuild "${prodargs[@]}" "$finpkg"
    then
        errprod; exit 1
    fi

    # verify
    echo "verifying..."
    /usr/sbin/pkgutil --check-signature "$finpkg"
    /usr/sbin/spctl -a -v --type install "$finpkg"

    # notarization
    if [[ -n "$notp" ]]
    then
        echo "submitting for notarization..."
        if /usr/bin/xcrun notarytool submit "$finpkg" --keychain-profile "$notp" --wait
        then
            /usr/bin/xcrun stapler staple "$finpkg"
        else
            errntry; exit 1
        fi
    fi

    # disk image
    if [[ -n "$dmg" ]]
    then
        echo "wrapping in a disk image..."
        dmgdir="$(/usr/bin/mktemp -d)"
        /bin/cp "$finpkg" "$dmgdir/"
        /usr/sbin/diskutil image create from --volumeName "$pkgp" "$dmgdir" "$pkgp.dmg"
        /bin/rm -rf "$dmgdir"
    fi

fi
