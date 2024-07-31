#!/bin/bash
# List all IPv6 addresses assigned to the interface ens4
ipv6_addresses=$(ip -6 addr show dev ens4 | grep inet6 | awk '{print $2}')

# Loop through each IPv6 address and delete it
for addr in $ipv6_addresses; do
    sudo ip -6 addr del $addr dev ens4
done
