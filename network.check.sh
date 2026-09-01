#!/bin/bash
# shellcheck disable=SC2128


# Check network stuff. Outputs a JSON object:
# - active interfaces
# - primary service (friendly name + interface)
# - link status
# - VPN interfaces: utun with a real, non-link-local address
# - captive portal detection
# - IPv4: gateway, local address, external IP, DHCP lease, ping (loss + RTT)
# - IPv6: gateway, local address, external IP, ping (loss + RTT), if a gateway is present
# - Wi-Fi: SSID, signal / noise
# - DNS: search domain, resolution, reverse lookup, configured servers
# - Proxy (http/https/socks): enabled, server, port

# Standard deviation (stddev in output) for RTT (packet round trip):

# - <5 ms — excellent, imperceptible for anything
# - 5–20 ms — fine for general use, gaming, video calls
# - 20–30 ms — starting to be noticeable for real-time voice/video and competitive gaming
# - 30–50 ms — bad for VoIP/gaming (audible glitches, input lag spikes); still fine for browsing/streaming (buffered)
# - >50 ms — bad even for casual use; something's actively wrong (congestion, weak Wi-Fi, bufferbloat)

# Usage: sudo ./network.check.sh

# Execute as root.



##### check for root execution #####

if [ "$EUID" != 0 ]
then
      printf "\nThis script must be executed by the root user. Exiting...\n"; exit
fi



##### variables & functions #####

dfltrt="$(/sbin/route get default 2> /dev/null)"
gtwyip="$(printf '%s' "$dfltrt" | /usr/bin/awk '/gateway:/{print $2}')"
ntwkif="$(printf '%s' "$dfltrt" | /usr/bin/awk '/interface:/{print $2}')"

cptprt="$(/usr/bin/curl -sS --max-time 5 http://captive.apple.com/hotspot-detect.html 2> /dev/null)"
dhcpls="/var/db/dhcpclient/leases/$ntwkif.plist"
dnsapl=($(/usr/bin/dig +short apple.com 2> /dev/null))
dnsggl=($(/usr/bin/dig +short -x 8.8.8.8 2> /dev/null))
dnsnpc=($(/usr/bin/dig +short nonpunctual.org 2> /dev/null))
dnssrv=($(/usr/sbin/scutil --dns | /usr/bin/awk '/nameserver\[[0-9]+\]/{print $3}' | /usr/bin/sort -u))
domsrc=($(/usr/sbin/scutil --dns | /usr/bin/awk '/search domain\[[0-9]+\]/{print $4}' | /usr/bin/sort -u))
extip4="$(/usr/bin/curl -4 -sS --max-time 5 ifconfig.me 2> /dev/null)"
extip6="$(/usr/bin/curl -6 -sS --max-time 5 ifconfig.me 2> /dev/null)"
ifcnfg="$(/sbin/ifconfig "$ntwkif" 2> /dev/null)"
ip4adr="$(printf '%s' "$ifcnfg" | /usr/bin/awk '/inet /{print $2}')"
ip6adr="$(printf '%s' "$ifcnfg" | /usr/bin/awk '/inet6/ && !/fe80/ {print $2; exit}')"
lnksts="$(printf '%s' "$ifcnfg" | /usr/bin/awk '/status:/{print $2}')"
ntwrks=($(/usr/sbin/scutil --nwi | /usr/bin/awk '/Network interfaces/{print substr($0,21)}' | /usr/bin/tr ' ' '\n'))

png4rw="$(/sbin/ping -c 10 -t 2 8.8.8.8 2>&1)"
png4ls="$(printf '%s' "$png4rw" | /usr/bin/awk -F ',' '/packet/{gsub(/^ /, "", $3); print $3}')"
png4rt="$(printf '%s' "$png4rw" | /usr/bin/awk -F'= ' '/round-trip/{print $2}')"


# extract the value of a single "Key : Value" line from scutil --proxy output
scutil_val(){
	printf '%s' "$pxyout" | /usr/bin/awk -F' : ' -v k="$1" '$1 ~ "^[[:space:]]*" k "$" {print $2}'
}
pxyout="$(/usr/sbin/scutil --proxy 2> /dev/null)"
hprxon="$(scutil_val HTTPEnable)"
hprxnm="$(scutil_val HTTPProxy)"
hprxpt="$(scutil_val HTTPPort)"
sprxon="$(scutil_val HTTPSEnable)"
sprxnm="$(scutil_val HTTPSProxy)"
sprxpt="$(scutil_val HTTPSPort)"
sckson="$(scutil_val SOCKSEnable)"
scksnm="$(scutil_val SOCKSProxy)"
sckspt="$(scutil_val SOCKSPort)"
pxacon="$(scutil_val ProxyAutoConfigEnable)"
pxacnm="$(scutil_val ProxyAutoConfigURLString)"
pxacds="$(scutil_val ProxyAutoDiscoveryEnable)"

routr4=($(/usr/sbin/netstat -nr -f inet | /usr/bin/awk '!/lo0/&&/default/{print $2}'))
routr6=($(/usr/sbin/netstat -nr -f inet6 | /usr/bin/awk '/^default/&&/'"$ntwkif"'/{print $2}'))
svcnam="$(/usr/sbin/networksetup -listnetworkserviceorder | /usr/bin/awk -v d="$ntwkif" '$0 ~ "Device: " d "\\)" { sub(/^\([0-9]+\) /, "", prev); print prev } { prev = $0 }')"

wfdata="$(/usr/sbin/system_profiler SPAirPortDataType -json 2> /dev/null | /usr/bin/jq -r --arg d "$ntwkif" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name==$d) | [(.spairport_current_network_information.spairport_signal_noise // empty), (.spairport_current_network_information.spairport_network_channel // empty)] | @tsv' 2> /dev/null)"
wfchnl="$(printf '%s' "$wfdata" | /usr/bin/awk -F'\t' '{split($2,a," "); print a[1]}')"
wfrssi="$(printf '%s' "$wfdata" | /usr/bin/awk -F'\t' '{print $1}')"


# captive-portal response
if [ -z "$cptprt" ]
then
	cptval="unknown"
elif printf '%s' "$cptprt" | /usr/bin/grep -q "Success"
then
	cptval="no"
else
	cptval="yes"
fi


# DHCP lease details
if dhcppl="$(/usr/libexec/PlistBuddy -x -c 'print LeaseStartDate' "$dhcpls" 2> /dev/null)"
then
	dhcpts="$(printf '%s' "$dhcppl" | /usr/bin/xmllint --xpath 'string(/plist/date)' - 2> /dev/null)"
	dhcpdr="$(/usr/sbin/ipconfig getoption "$ntwkif" lease_time 2> /dev/null)"
	dhcpsv="$(/usr/sbin/ipconfig getoption "$ntwkif" server_identifier 2> /dev/null)"
	epchdt="$(/bin/date -j -f '%Y-%m-%dT%H:%M:%SZ' -u "$dhcpts" '+%s' 2> /dev/null)"

	if [ -n "$epchdt" ] && [ -n "$dhcpdr" ]
	then
		dhcpxp="$(/bin/date -j -r "$((epchdt + dhcpdr))" -u '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null)"
	fi
fi


# IPv6 reachability ping
if [ -n "$routr6" ]
then
	png6rw="$(/sbin/ping6 -c 5 2001:4860:4860::8888 2>&1)"
	png6ls="$(printf '%s' "$png6rw" | /usr/bin/awk -F ',' '/packet/{gsub(/^ /, "", $3); print $3}')"
	png6rt="$(printf '%s' "$png6rw" | /usr/bin/awk -F'= ' '/round-trip/{print $2}')"
fi


# collect utun interfaces (VPN)
for d in $(/sbin/ifconfig -l | /usr/bin/tr ' ' '\n' | /usr/bin/grep '^utun')
do
	/sbin/ifconfig "$d" | /usr/bin/grep -E '^[[:space:]]*inet6? ' | /usr/bin/grep -qv 'fe80' && vpnifs+=("$d")
done


# match current gateway / channel against known networks (SSID)
if [ -n "$wfchnl" ]
then
	mtchky="$(/usr/libexec/PlistBuddy -x -c 'print' /Library/Preferences/com.apple.wifi.known-networks.plist 2> /dev/null | /usr/bin/xmllint --xpath "string(/plist/dict/dict[.//key[.='IPv4NetworkSignature']/following-sibling::*[1][contains(text(), 'IPv4.Router=$gtwyip;')] and .//key[.='Channel']/following-sibling::*[1][text()='$wfchnl']]/key[.='SSID']/following-sibling::*[1])" - 2> /dev/null)"
	ssidnm="$(printf '%s' "$mtchky" | /usr/bin/base64 -D 2> /dev/null)"
fi


json_array(){
	if [ "$#" -eq 0 ]
	then
		printf '[]'
	else
		printf '%s\n' "$@" | /usr/bin/jq -R . | /usr/bin/jq -s -c .
	fi
}



##### output #####

svcstr="${svcnam:-unknown} ($ntwkif)"

if [ -z "$routr4" ] || [ -z "$extip4" ] || [ -z "$dnsapl" ]
then
	errstr="no working IPv4 internet connection detected"
fi

activejson="$(json_array "${ntwrks[@]}")"
vpnjson="$(json_array "${vpnifs[@]}")"
gw4json="$(json_array "${routr4[@]}")"
gw6json="$(json_array "${routr6[@]}")"
domjson="$(json_array "${domsrc[@]}")"
dnssrvjson="$(json_array "${dnssrv[@]}")"
aplresjson="$(json_array "${dnsapl[@]}")"
npcresjson="$(json_array "${dnsnpc[@]}")"
gglresjson="$(json_array "${dnsggl[@]}")"

/usr/bin/jq -n \
	--argjson active_interfaces "$activejson" \
	--arg primary_service "$svcstr" \
	--arg link_status "${lnksts:-unknown}" \
	--argjson vpn_active "$vpnjson" \
	--arg captive_portal "$cptval" \
	--argjson ipv4_gateway "$gw4json" \
	--arg ipv4_local_address "${ip4adr:-not found}" \
	--arg ipv4_external_ip "${extip4:-not found}" \
	--arg ipv4_ping_loss "${png4ls:-unknown}" \
	--arg ipv4_ping_rtt "$png4rt" \
	--arg dhcp_server "$dhcpsv" \
	--arg dhcp_lease_start "$dhcpts" \
	--arg dhcp_lease_expires "$dhcpxp" \
	--argjson ipv6_gateway "$gw6json" \
	--arg ipv6_local_address "${ip6adr:-not found}" \
	--arg ipv6_external_ip "${extip6:-not found}" \
	--arg ipv6_ping_loss "$png6ls" \
	--arg ipv6_ping_rtt "$png6rt" \
	--arg wifi_signal_noise "$wfrssi" \
	--arg wifi_network "$ssidnm" \
	--argjson dns_search_domain "$domjson" \
	--argjson dns_configured_servers "$dnssrvjson" \
	--argjson dns_resolve_apple "$aplresjson" \
	--argjson dns_resolve_nonpunctual "$npcresjson" \
	--argjson dns_reverse_lookup "$gglresjson" \
	--arg proxy_http_enabled "$hprxon" \
	--arg proxy_http_server "$hprxnm" \
	--arg proxy_http_port "$hprxpt" \
	--arg proxy_https_enabled "$sprxon" \
	--arg proxy_https_server "$sprxnm" \
	--arg proxy_https_port "$sprxpt" \
	--arg proxy_socks_enabled "$sckson" \
	--arg proxy_socks_server "$scksnm" \
	--arg proxy_socks_port "$sckspt" \
	--arg proxy_pac_enabled "$pxacon" \
	--arg proxy_pac_url "$pxacnm" \
	--arg proxy_autodiscovery_enabled "$pxacds" \
	--arg error "$errstr" \
	'(
		(if $wifi_network != "" then {ssid: $wifi_network} else {} end)
		+ (if $wifi_signal_noise != "" then ($wifi_signal_noise | capture("(?<signal>-?[0-9]+ dBm) / (?<noise>-?[0-9]+ dBm)")) else {} end)
	) as $wifi
	| (
		if $ipv4_ping_rtt != "" then
			($ipv4_ping_rtt | capture("(?<min>[0-9.]+)/(?<avg>[0-9.]+)/(?<max>[0-9.]+)/(?<stddev>[0-9.]+) ms") | with_entries(.value |= (. + " ms")))
		else null end
	) as $ipv4_rtt
	| (
		if $ipv6_ping_rtt != "" then
			($ipv6_ping_rtt | capture("(?<min>[0-9.]+)/(?<avg>[0-9.]+)/(?<max>[0-9.]+)/(?<stddev>[0-9.]+) ms") | with_entries(.value |= (. + " ms")))
		else null end
	) as $ipv6_rtt
	| (
		if $dhcp_lease_start != "" then
			{server: $dhcp_server, lease_start: $dhcp_lease_start, lease_expires: $dhcp_lease_expires}
		else null end
	) as $dhcp
	| {
		active_interfaces: $active_interfaces,
		primary_service: $primary_service,
		link_status: $link_status,
		vpn_active: $vpn_active,
		captive_portal: $captive_portal,
		ipv4: (
			{gateway: $ipv4_gateway, local_address: $ipv4_local_address, external_ip: $ipv4_external_ip, ping: {loss: $ipv4_ping_loss, rtt: $ipv4_rtt}}
			+ (if $dhcp != null then {dhcp: $dhcp} else {} end)
		),
		ipv6: (
			{gateway: $ipv6_gateway, local_address: $ipv6_local_address, external_ip: $ipv6_external_ip}
			+ (if $ipv6_ping_loss != "" then {ping: {loss: $ipv6_ping_loss, rtt: $ipv6_rtt}} else {} end)
		)
	}
	+ (if ($wifi | length) > 0 then {wifi: $wifi} else {} end)
	+ {
		dns: {
			search_domain: $dns_search_domain,
			configured_servers: $dns_configured_servers,
			resolve_apple: $dns_resolve_apple,
			resolve_nonpunctual: $dns_resolve_nonpunctual,
			reverse_lookup: $dns_reverse_lookup
		},
		proxy: {
			http: {enabled: ($proxy_http_enabled == "1"), server: $proxy_http_server, port: (if $proxy_http_port == "" then 0 else ($proxy_http_port | tonumber) end)},
			https: {enabled: ($proxy_https_enabled == "1"), server: $proxy_https_server, port: (if $proxy_https_port == "" then 0 else ($proxy_https_port | tonumber) end)},
			socks: {enabled: ($proxy_socks_enabled == "1"), server: $proxy_socks_server, port: (if $proxy_socks_port == "" then 0 else ($proxy_socks_port | tonumber) end)},
			auto: {config_enabled: ($proxy_pac_enabled == "1"), config_url: $proxy_pac_url, autodiscovery_enabled: ($proxy_autodiscovery_enabled == "1")}
		}
	}
	+ (if $error != "" then {error: $error} else {} end)'
