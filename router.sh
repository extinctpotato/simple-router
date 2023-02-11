#!/usr/bin/env bash
set -e

this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

eval "$("$this_dir"/utils/export_config.py "$1")"

IPS_IN_SUBNET=$(nmap -sL -n $interfaces__gateway \
    | awk '/Nmap scan report/{print $NF}' \
    | head -n -1 \
    | tail -n +2
)
IPS_FOR_DHCP=$(echo "$IPS_IN_SUBNET" \
    | head -n +${dhcp__max_leases} \
    | tail -n +${dhcp__lease_offset} \
    | sed -e 1b -e '$!d' \
    | tr '\n' ',' \
    | sed 's/,$/\n/'
)
C='-m comment --comment "simple-router"'

_term() {
    ip link set dev $interfaces__lan down
    ip addr del $interfaces__gateway dev $interfaces__lan
	iptables-save | grep -v "simple-router" | iptables-restore
	exit 0
}

echo "IP range for DHCP: $IPS_FOR_DHCP"

trap _term EXIT

set -x

ip addr add $interfaces__gateway dev $interfaces__lan
ip link set dev $interfaces__lan up

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -o $interfaces__wan -j MASQUERADE $C
iptables -I FORWARD 1 -i $interfaces__lan -j ACCEPT $C
iptables -I FORWARD 1 -o $interfaces__lan -m state --state RELATED,ESTABLISHED -j ACCEPT $C

/usr/sbin/dnsmasq \
    --interface=$interfaces__lan \
    --bind-interfaces \
    --dhcp-range=$IPS_FOR_DHCP,2m \
    --log-dhcp \
    --leasefile-ro \
    --dhcp-authoritative \
    --conf-dir=dnsmasq_configs,*.dnsmasq.conf \
    -d
