#!/bin/sh


# usage: ./configure.fleet.printers.sh <path/to/printers.csv>
# arg "$1" is the path to a .csv with the printer data

# input:
# - a .csv file with the following columns (header row required): 
# - name
# - location
# - uri
# - display_name

# example:

# name,location,uri,display_name
# Floor2-LaserJet,Floor 2,ipp://192.0.2.10/ipp/print,Floor 2 printer
# Floor3-Inkjet,Floor 3,ipp://192.0.2.11/ipp/print,Floor 3 printer
# Lobby-ColorCopier,Lobby,ipp://192.0.2.12/ipp/print,Lobby copier

# output (stdout):
# - a printer install script per printer
# - a packages.yml block


# variables
csvpath="$1"
divider="--------------------------------------------------------------------------------"
yamltxt="software:
  packages:"


# exit conditions
if [ -z "$csvpath" ] || [ ! -r "$csvpath" ]
then
    echo "Usage: $0 <printers.csv>. File missing or unreadable. Exiting..." >&2; exit 1
fi


# generate one install script per printer, and collect the packages.yml block
{
    read -r header
    while IFS=',' read -r name location uri display_name
    do
        [ -z "$name" ] && continue

        slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

        echo "$divider"
        echo "# ../lib/macos/scripts/$slug.sh"
        echo "$divider"
        cat <<SCRIPT

#!/bin/sh

PRINTER_NAME="$name"
PRINTER_LOCATION="$location"
PRINTER_URI="$uri"

/usr/sbin/lpadmin -p "\$PRINTER_NAME" -L "\$PRINTER_LOCATION" -E -v "\$PRINTER_URI" -m everywhere -o printer-is-shared=false
SCRIPT
        echo

        yamltxt="$yamltxt
    - path: ../lib/macos/scripts/$slug.sh
      display_name: $display_name
      self_service: true"
    done
} < "$csvpath"


# print the packages.yml block
echo "$divider"
echo "# packages.yml"
echo "$divider"
echo "$yamltxt"
echo "$divider"
echo
