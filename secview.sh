#!/usr/bin/env bash
# Ubuntu 24.04 Security Overview Script
# Read-only diagnostic – no system changes

set -euo pipefail

SEP="============================================================"

echo "$SEP"
echo "SYSTEM & OS"
echo "$SEP"
lsb_release -a 2>/dev/null || cat /etc/os-release
uname -r
uptime

echo
echo "$SEP"
echo "KERNEL SECURITY FEATURES"
echo "$SEP"

# Secure Boot
if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state
else
    echo "mokutil not installed (Secure Boot status unknown)"
fi

# Kernel lockdown
if [[ -f /sys/kernel/security/lockdown ]]; then
    echo -n "Kernel Lockdown Mode: "
    cat /sys/kernel/security/lockdown
else
    echo "Kernel Lockdown: not enabled"
fi

# KASLR
echo -n "KASLR: "
cat /proc/sys/kernel/randomize_va_space

echo
echo "$SEP"
echo "APPARMOR (MANDATORY ACCESS CONTROL)"
echo "$SEP"
if systemctl is-active --quiet apparmor; then
    echo "AppArmor: ENABLED"
    aa-status
else
    echo "AppArmor: DISABLED"
fi

echo
echo "$SEP"
echo "FIREWALL & NETWORK FILTERING"
echo "$SEP"

# UFW
if command -v ufw >/dev/null 2>&1; then
    ufw status verbose
else
    echo "ufw not installed"
fi

# nftables (used by default in Ubuntu)
if systemctl is-active --quiet nftables; then
    echo
    echo "nftables: ACTIVE"
    nft list ruleset | head -n 40
else
    echo
    echo "nftables: not active"
fi

echo
echo "$SEP"
echo "SYSTEM UPDATES & PATCHING"
echo "$SEP"

# Unattended upgrades
if dpkg -l unattended-upgrades >/dev/null 2>&1; then
    echo "unattended-upgrades: INSTALLED"
    grep -E 'APT::Periodic|Unattended-Upgrade' /etc/apt/apt.conf.d/* 2>/dev/null
else
    echo "unattended-upgrades: NOT installed"
fi

echo
echo "$SEP"
echo "USER & AUTHENTICATION HARDENING"
echo "$SEP"

# Password policy
grep -E 'PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE' /etc/login.defs

# Root login
echo
echo "Root account status:"
passwd -S root

# sudo configuration
echo
echo "Sudo configuration:"
sudo -l -U "$USER" 2>/dev/null | head -n 20 || echo "No sudo access for current user"

echo
echo "$SEP"
echo "SSH HARDENING"
echo "$SEP"
if systemctl is-active --quiet ssh; then
    echo "SSH: ACTIVE"
    grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)' \
        /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
else
    echo "SSH: NOT running"
fi

echo
echo "$SEP"
echo "AUDITING & LOGGING"
echo "$SEP"

# auditd
if systemctl is-active --quiet auditd; then
    echo "auditd: ACTIVE"
    auditctl -s
else
    echo "auditd: NOT active"
fi

# systemd journal persistence
echo
echo "systemd-journald storage:"
grep -E '^Storage=' /etc/systemd/journald.conf 2>/dev/null || echo "Default (auto)"

echo
echo "$SEP"
echo "DISK & FILESYSTEM SECURITY"
echo "$SEP"

# Encryption
lsblk -o NAME,FSTYPE,TYPE,SIZE,MOUNTPOINT | grep -E 'crypt|luks' || echo "No encrypted block devices detected"

# Mount options
echo
echo "Mount options (nosuid,nodev,noexec):"
mount | grep -E 'nosuid|nodev|noexec'

echo
echo "$SEP"
echo "SNAP SECURITY (SANDBOXING)"
echo "$SEP"
if command -v snap >/dev/null 2>&1; then
    snap version
    snap list --all | wc -l | xargs echo "Installed snaps:"
else
    echo "snap not installed"
fi

echo
echo "$SEP"
echo "SUMMARY"
echo "$SEP"
echo "✔ Kernel hardening, MAC (AppArmor), firewall, updates, auth, SSH, auditing"
echo "Review any DISABLED or NOT active items above."


echo "================ SELINUX STATUS ================"

# Check if SELinux is supported by the kernel
if [[ ! -d /sys/fs/selinux ]]; then
    echo "SELinux: NOT enabled in kernel"
    exit 0
fi

# Check sestatus tool
if command -v sestatus >/dev/null 2>&1; then
    sestatus
else
    echo "sestatus not installed"
fi

echo
echo "Current mode (runtime):"
if [[ -f /sys/fs/selinux/enforce ]]; then
    if [[ "$(cat /sys/fs/selinux/enforce)" -eq 1 ]]; then
        echo "Enforcing"
    else
        echo "Permissive"
    fi
else
    echo "Disabled"
fi

echo
echo "Configured mode (boot):"
if [[ -f /etc/selinux/config ]]; then
    grep -E '^SELINUX=' /etc/selinux/config
else
    echo "/etc/selinux/config not present"
fi
