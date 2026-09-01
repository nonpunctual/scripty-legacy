#!/bin/bash


# Reports on devices/connections near a Mac:
# - ARP table: LAN neighbors (IP + MAC)
# - Bonjour/mDNS: service types being advertised nearby (~3s browse)
# - active connections: remote hosts a Mac is currently talking to
# - DHCP leases: devices a Mac has handed an IP via Internet Sharing

# NOTE: mDNS services re-announce on their own periodic schedule, not
# continuously, so a fixed browse window can land between announcements
# & return empty.

# Usage: ./network.device.list.sh


leases='/var/db/dhcpd_leases'
bonjour="$(/usr/bin/mktemp)"
trap 'rm -f "$bonjour"' EXIT

echo "== LAN neighbors (arp) =="
/usr/sbin/arp -a | /usr/bin/awk '$4!="ff:ff:ff:ff:ff:ff" && $4!="(incomplete)" && $1!~/mdns/ {gsub(/[()]/,"",$2); print $2"\t"$4}'

echo "
== nearby services (bonjour, ~3s browse, best-effort) =="
/usr/bin/dns-sd -B _services._dns-sd._udp local > "$bonjour" 2>&1 &
dpid=$!
/bin/sleep 3
/bin/kill "$dpid"
wait "$dpid" 2> /dev/null
/usr/bin/awk '$1=="Add"{print $NF}' "$bonjour" | /usr/bin/sort -u

echo "
== active connections (this Mac -> remote) =="
/usr/sbin/lsof -i -n -P 2> /dev/null | /usr/bin/awk '$0~/ESTABLISHED/{n=split($9,a,"->"); print a[2]}' | /usr/bin/sed 's/:[0-9]*$//' | /usr/bin/sort -u

if [[ -e "$leases" ]]
then
	echo "
== DHCP leases handed out (Internet Sharing) =="
	/usr/bin/awk -F= '
	/name=/{name=$2}
	/ip_address=/{ip=$2}
	/hw_address=/{mac=$2; sub(/^1,/,"",mac)}
	/lease=/{printf "%s\t%s\t%s\n", name, ip, mac}
	' "$leases"
fi
