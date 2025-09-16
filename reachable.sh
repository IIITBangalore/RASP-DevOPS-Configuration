#!/bin/bash

# File containing IP addresses, one per line
IP_FILE="ips.txt"

# Arrays to hold results
reachable=()
unreachable=()

while IFS= read -r ip; do
    if [ -n "$ip" ]; then
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            echo "[OK] $ip is reachable"
            reachable+=("$ip")
        else
            echo "[FAIL] $ip is NOT reachable"
            unreachable+=("$ip")
        fi
    fi
done < "$IP_FILE"

echo
echo "==== Reachable IPs ===="
for ip in "${reachable[@]}"; do
    echo "$ip"
done

echo
echo "==== Unreachable IPs ===="
for ip in "${unreachable[@]}"; do
    echo "$ip"
done

# Optionally save to files
echo "${reachable[@]}" | tr ' ' '\n' > reachable.txt
echo "${unreachable[@]}" | tr ' ' '\n' > unreachable.txt
