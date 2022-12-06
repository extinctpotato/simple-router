#!/bin/sh
set -e

WAN=wlp0s20f3
#LAN=enp58s0u1u4u3
LAN=enp0s20f0u4
GW="10.3.189.1/24"
DHCP_MAX_LEASES=90
DHCP_LEASE_OFFSET=10
IPS_IN_SUBNET=$(nmap -sL -n $GW \
    | awk '/Nmap scan report/{print $NF}' \
    | head -n -1 \
    | tail -n +2
)
IPS_FOR_DHCP=$(echo "$IPS_IN_SUBNET" \
    | head -n +${DHCP_MAX_LEASES} \
    | tail -n +${DHCP_LEASE_OFFSET} \
    | sed -e 1b -e '$!d' \
    | tr '\n' ',' \
    | sed 's/,$/\n/'
)
C='-m comment --comment "simple-router"'

_term() {
    ip addr del $GW dev $LAN
	iptables-save | grep -v "simple-router" | iptables-restore
	exit 0
}

echo "IP range for DHCP: $IPS_FOR_DHCP"

trap _term EXIT

set -x

ip addr add $GW dev $LAN

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE $C
iptables -I FORWARD 1 -i $LAN -j ACCEPT $C
iptables -I FORWARD 1 -o $LAN -m state --state RELATED,ESTABLISHED -j ACCEPT $C

/usr/sbin/dnsmasq \
    --interface=$LAN \
    --bind-interfaces \
    --dhcp-range=$IPS_FOR_DHCP,12h \
    --log-dhcp \
    --leasefile-ro \
    --dhcp-authoritative \
    --conf-dir=dnsmasq_configs,*.dnsmasq.conf \
    -d
