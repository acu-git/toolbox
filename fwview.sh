#!/usr/bin/env bash
# Firewall Presence & Status Checker (Ubuntu-focused, read-only)

set -euo pipefail
SEP="============================================================"

echo "$SEP"
echo "FIREWALL PRESENCE & STATUS"
echo "$SEP"

# Helper
svc_status() {
    local svc="$1"
    if systemctl list-unit-files | grep -q "^${svc}\.service"; then
        systemctl is-active --quiet "$svc" \
            && echo "$svc: ACTIVE" \
            || echo "$svc: INSTALLED but NOT active"
    else
        echo "$svc: NOT installed"
    fi
}

echo
echo "High-level firewall managers:"
svc_status ufw
svc_status firewalld
svc_status nftables

echo
echo "$SEP"
echo "UFW DETAILS"
echo "$SEP"
if command -v ufw >/dev/null 2>&1; then
    ufw status verbose || echo "ufw present but inactive"
else
    echo "ufw not installed"
fi

echo
echo "$SEP"
echo "NFTABLES DETAILS"
echo "$SEP"
if command -v nft >/dev/null 2>&1; then
    if systemctl is-active --quiet nftables; then
        echo "nftables service: ACTIVE"
        nft list ruleset | head -n 40
    else
        echo "nftables binary present, service not active"
    fi
else
    echo "nft command not available"
fi

echo
echo "$SEP"
echo "IPTABLES (LEGACY / NFT BACKEND)"
echo "$SEP"
if command -v iptables >/dev/null 2>&1; then
    echo "iptables backend:"
    iptables -V

    echo
    echo "iptables rules present:"
    iptables -L -n -v | head -n 20
else
    echo "iptables not installed"
fi

echo
echo "$SEP"
echo "KERNEL NETFILTER HOOKS (GROUND TRUTH)"
echo "$SEP"
if command -v nft >/dev/null 2>&1; then
    nft list tables >/dev/null 2>&1 \
        && echo "Netfilter tables present (firewall likely active)" \
        || echo "No netfilter tables loaded"
else
    echo "Unable to inspect netfilter tables"
fi

echo
echo "$SEP"
echo "SUMMARY"
echo "$SEP"
echo "- ACTIVE service indicates managing firewall rules"
echo "- nftables is the default backend on modern Ubuntu"
echo "- UFW and firewalld are frontends (only one should manage rules)"
echo "- Netfilter tables indicate actual enforcement"
