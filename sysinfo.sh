#!/bin/bash

# sysinfo-professional.sh
# Professional System Information Reporter for Ubuntu 24.04
# Author: System Administrator
# Version: 1.0.0
# License: MIT

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CONFIGURATION
# ============================================================================
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REQUIRED_UBUNTU_VERSION="24.04"
readonly REPORT_TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
readonly OUTPUT_DIR="${SCRIPT_DIR}/sysinfo_reports"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"

# Color codes for output (only if terminal supports it)
if [[ -t 1 ]] && tput colors &>/dev/null; then
    readonly RED=$(tput setaf 1)
    readonly GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3)
    readonly BLUE=$(tput setaf 4)
    readonly MAGENTA=$(tput setaf 5)
    readonly CYAN=$(tput setaf 6)
    readonly WHITE=$(tput setaf 7)
    readonly BOLD=$(tput bold)
    readonly RESET=$(tput sgr0)
    readonly DIM=$(tput dim)
    readonly ULINE=$(tput smul)
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
    readonly BOLD='' RESET='' DIM='' ULINE=''
fi

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

validate_environment() {
    echo "${BOLD}${CYAN}🔍 Validating environment...${RESET}" >&2
    
    # Check for Ubuntu 24.04
    if [[ ! -f "/etc/os-release" ]]; then
        log_error "System file /etc/os-release not found"
        return 1
    fi
    
    local os_id os_version
    os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    
    if [[ "${os_id,,}" != "ubuntu" ]]; then
        log_error "This script requires Ubuntu. Detected OS: $os_id"
        return 1
    fi
    
    if [[ "$os_version" != "$REQUIRED_UBUNTU_VERSION" ]]; then
        log_warning "Script tested on Ubuntu $REQUIRED_UBUNTU_VERSION. Detected: $os_version"
        [[ "${FORCE:-0}" -eq 1 ]] || {
            echo "${YELLOW}Use --force to continue anyway${RESET}" >&2
            return 1
        }
    fi
    
    # Check required commands
    local required_cmds=(
        "lshw" "lscpu" "lsblk" "free" "df" "uptime" "hostnamectl"
        "systemctl" "journalctl" "ss" "ip" "dmidecode"
    )
    
    local missing_cmds=()
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_warning "Missing optional commands: ${missing_cmds[*]}"
        echo "${YELLOW}Some reports may be limited. Install with:${RESET}" >&2
        echo "  sudo apt install lshw util-linux pciutils dmidecode" >&2
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    echo "${GREEN}✓ Environment validated${RESET}" >&2
    return 0
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo "${BLUE}[INFO]${RESET} $*" >&2
    logger -t "$SCRIPT_NAME" "INFO: $*"
}

log_warning() {
    echo "${YELLOW}[WARNING]${RESET} $*" >&2
    logger -t "$SCRIPT_NAME" "WARNING: $*"
}

log_error() {
    echo "${RED}[ERROR]${RESET} $*" >&2
    logger -t "$SCRIPT_NAME" "ERROR: $*"
}

log_success() {
    echo "${GREEN}[SUCCESS]${RESET} $*" >&2
    logger -t "$SCRIPT_NAME" "SUCCESS: $*"
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

generate_header() {
    cat <<EOF
===================================================
SYSTEM INFORMATION REPORT
===================================================
Generated: $(date)
Hostname: $(hostname -f) which FQDN is $(hostname -A)
OS: Ubuntu $(grep '^VERSION=' /etc/os-release | cut -d= -f2 | tr -d '"')
Kernel: $(uname -r)
Uptime: $(uptime -p | sed 's/up //')
Report ID: ${REPORT_TIMESTAMP}
===================================================

EOF
}

# ----------------------------------------------------------------------------
# 1. SYSTEM OVERVIEW
# ----------------------------------------------------------------------------

report_system_overview() {
    echo "${BOLD}${ULINE}1. SYSTEM OVERVIEW${RESET}"
    echo "======================"
    
    # Hostname and OS
    echo "${BOLD}Host Information:${RESET}"
    hostnamectl | grep -E "(Static hostname|Icon name|Chassis|Machine ID|Boot ID)" | \
        sed 's/^/  /'
    echo
    
    # OS Details
    echo "${BOLD}Operating System:${RESET}"
    if [[ -f /etc/os-release ]]; then
        grep -E "^(PRETTY_NAME|VERSION|VERSION_ID|VERSION_CODENAME)" /etc/os-release | \
            while IFS='=' read -r key value; do
                printf "  %-20s: %s\n" "$key" "$(echo "$value" | tr -d '"')"
            done
    fi
    echo
    
    # Kernel Information
    echo -e "${BOLD}Kernel Information:${RESET}"
    echo -e "kernel name is:      $(uname -s)"
    echo -e "kernel-release is:   $(uname -r)"
    echo -e "kernel version is:   $(uname -v)"
    echo -e "machine hardware is: $(uname -m)"
    echo -e "processor type is:   $(uname -p)"
    echo -e "h/w platform is:     $(uname -i)"
    echo -e "operating system is: $(uname -o)"
    echo -e "desktop env. is:     $(echo $DESKTOP_SESSION) - "
    echo -e "$(env | grep XDG_CURRENT_DESKTOP)"
    #
    echo -e "Distributor ID:      $(lsb_release -cs)"
    echo -e "Description:         $(lsb_release -is)"
    echo -e "Release:             $(lsb_release -ds)"
    echo -e "Codename:            $(lsb_release -rs)"
    echo
    
    # System Uptime
    echo "${BOLD}System Uptime:${RESET}"
    uptime | sed 's/^/  /'
    echo
    
    # Last Reboot
    echo "${BOLD}Last Reboot:${RESET}"
    who -b | sed 's/^/  /'
    echo
    
    # Time and Date
    echo "${BOLD}Time Configuration:${RESET}"
    timedatectl | grep -E "(Local time|Universal time|RTC time|Time zone)" | \
        sed 's/^/  /'
    echo
    
    # Systemd Version
    if command -v systemctl &>/dev/null; then
        echo "${BOLD}Systemd Version:${RESET}"
        systemctl --version | head -1 | sed 's/^/  /'
        echo
    fi
}

# ----------------------------------------------------------------------------
# 2. HARDWARE INFORMATION
# ----------------------------------------------------------------------------

report_hardware() {
    echo "${BOLD}${ULINE}2. HARDWARE INFORMATION${RESET}"
    echo "============================"
    
    # CPU Information
    echo "${BOLD}CPU Information:${RESET}"
    if command -v lscpu &>/dev/null; then
        lscpu | grep -E "(Architecture|CPU\(s\)|Thread|Core|Model name|MHz|max MHz|min MHz)" | \
            sed 's/^/  /'
    else
        grep -E "(model name|cpu MHz|cpu cores)" /proc/cpuinfo | head -3 | sed 's/^/  /'
    fi
    echo
    
    # Memory Information
    echo "${BOLD}Memory Information:${RESET}"
    free -h | sed 's/^/  /'
    echo
    echo "  Memory Details:"
    grep -E "(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree)" /proc/meminfo | \
        sed 's/^/    /'
    echo
    
    # BIOS/UEFI Information
    echo "${BOLD}BIOS/UEFI Information:${RESET}"
    if sudo -n true 2>/dev/null && command -v dmidecode &>/dev/null; then
        sudo dmidecode -t bios 2>/dev/null | grep -E "(Vendor|Version|Release Date|BIOS Revision)" | \
            sed 's/^/  /' || echo "  [Requires sudo privileges]"
    else
        echo "  [dmidecode not available or requires sudo]"
    fi
    echo
    
    # System Manufacturer
    echo "${BOLD}System Manufacturer:${RESET}"
    if sudo -n true 2>/dev/null && command -v dmidecode &>/dev/null; then
        sudo dmidecode -t system 2>/dev/null | grep -E "(Manufacturer|Product Name|Serial Number|UUID)" | \
            sed 's/^/  /' || echo "  [Requires sudo privileges]"
    else
        echo "  [dmidecode not available or requires sudo]"
    fi
    echo
}

# ----------------------------------------------------------------------------
# 3. STORAGE INFORMATION
# ----------------------------------------------------------------------------

report_storage() {
    echo "${BOLD}${ULINE}3. STORAGE INFORMATION${RESET}"
    echo "==========================="
    
    # Disk Usage
    echo "${BOLD}Disk Usage Summary:${RESET}"
    df -h --type=ext4 --type=xfs --type=btrfs --type=vfat --type=ntfs 2>/dev/null | \
        sed 's/^/  /'
    echo
    
    # Detailed Block Devices
    echo "${BOLD}Block Device Details:${RESET}"
    if command -v lsblk &>/dev/null; then
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,UUID | sed 's/^/  /'
    else
        echo "  [lsblk not available]"
    fi
    echo
    
    # RAID Information
    echo "${BOLD}RAID Status:${RESET}"
    if [[ -f /proc/mdstat ]]; then
        grep -A 10 "md" /proc/mdstat | sed 's/^/  /'
    else
        echo "  No software RAID detected"
    fi
    echo
    
    # LVM Information
    echo "${BOLD}LVM Information:${RESET}"
    if command -v pvs &>/dev/null; then
        echo "  Physical Volumes:"
        sudo pvs 2>/dev/null | sed 's/^/    /' || echo "    [Requires sudo privileges]"
        echo
        echo "  Volume Groups:"
        sudo vgs 2>/dev/null | sed 's/^/    /' || echo "    [Requires sudo privileges]"
        echo
        echo "  Logical Volumes:"
        sudo lvs 2>/dev/null | sed 's/^/    /' || echo "    [Requires sudo privileges]"
    else
        echo "  LVM tools not installed"
    fi
    echo
    
    # Mount Options
    echo "${BOLD}Mount Options:${RESET}"
    mount | grep -E "(ext4|xfs|btrfs|vfat|ntfs)" | sed 's/^/  /'
    echo
}

# ----------------------------------------------------------------------------
# 4. NETWORK INFORMATION
# ----------------------------------------------------------------------------

report_network() {
    echo "${BOLD}${ULINE}4. NETWORK INFORMATION${RESET}"
    echo "==========================="
    
    # IP Addresses
    echo "${BOLD}Network Interfaces:${RESET}"
    ip -br addr show | sed 's/^/  /'
    echo
    
    # Routing Table
    echo "${BOLD}Routing Table:${RESET}"
    ip route show | sed 's/^/  /'
    echo
    
    # DNS Configuration
    echo "${BOLD}DNS Configuration:${RESET}"
    cat /etc/resolv.conf | grep -v "^#" | sed 's/^/  /'
    echo
    
    # Network Statistics
    echo "${BOLD}Network Statistics:${RESET}"
    ss -s | head -5 | sed 's/^/  /'
    echo
    
    # Listening Ports
    echo "${BOLD}Listening Ports:${RESET}"
    ss -tuln | head -20 | sed 's/^/  /'
    echo "  [Showing top 20 listening ports]"
    echo
    
    # Network Manager (if present)
    echo "${BOLD}Network Manager:${RESET}"
    if command -v nmcli &>/dev/null; then
        nmcli general status 2>/dev/null | sed 's/^/  /' || echo "  [NetworkManager not running]"
    else
        echo "  NetworkManager not installed"
    fi
    echo
    
    # Firewall Status
    echo "${BOLD}Firewall Status:${RESET}"
    if command -v ufw &>/dev/null; then
        sudo ufw status verbose 2>/dev/null | sed 's/^/  /' || echo "  [Requires sudo privileges]"
    elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --state 2>/dev/null | sed 's/^/  /' || echo "  [firewalld not running]"
    else
        echo "  No known firewall manager detected"
    fi
    echo
}

# ----------------------------------------------------------------------------
# 5. SECURITY INFORMATION
# ----------------------------------------------------------------------------

report_security() {
    echo "${BOLD}${ULINE}5. SECURITY INFORMATION${RESET}"
    echo "============================="
    
    # User Accounts
    echo "${BOLD}User Accounts:${RESET}"
    echo "  Sudo Users:"
    grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n' | sed 's/^/    /'
    echo
    
    # SSH Configuration
    echo "${BOLD}SSH Configuration:${RESET}"
    if [[ -f /etc/ssh/sshd_config ]]; then
        echo "  SSH Service Status:"
        systemctl is-active ssh 2>/dev/null | sed 's/^/    /' || echo "    Not installed"
        echo
        echo "  Important SSH Settings:"
        grep -E "^(PermitRootLogin|PasswordAuthentication|Port|Protocol)" /etc/ssh/sshd_config | \
            sed 's/^/    /'
    else
        echo "  SSH not installed"
    fi
    echo
    
    # Failed Login Attempts
    echo "${BOLD}Failed Login Attempts (last 24h):${RESET}"
    if [[ -f /var/log/auth.log ]]; then
        grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 | sed 's/^/  /' || \
            echo "  [No failed attempts or no permission]"
    else
        echo "  Auth log not accessible"
    fi
    echo
    
    # Package Updates
    echo "${BOLD}Security Updates:${RESET}"
    if command -v apt &>/dev/null; then
        apt list --upgradable 2>/dev/null | grep -i security | head -10 | sed 's/^/  /' || \
            echo "  No security updates pending or cannot check"
    fi
    echo
    
    # SELinux/AppArmor
    echo "${BOLD}Mandatory Access Control:${RESET}"
    if command -v aa-status &>/dev/null; then
        sudo aa-status 2>/dev/null | head -10 | sed 's/^/  /' || echo "  [AppArmor status check failed]"
    else
        echo "  AppArmor not installed"
    fi
    echo
}

# ----------------------------------------------------------------------------
# 6. SERVICE INFORMATION
# ----------------------------------------------------------------------------

report_services() {
    echo "${BOLD}${ULINE}6. SERVICE INFORMATION${RESET}"
    echo "==========================="
    
    # System Services
    echo "${BOLD}Critical Service Status:${RESET}"
    local critical_services=(
        "ssh" "cron" "systemd-logind" "systemd-networkd" "systemd-resolved"
        "dbus" "network-manager" "ufw" "snapd"
    )
    
    for service in "${critical_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            local status
            status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            printf "  %-25s: %s\n" "$service" "$status"
        fi
    done
    echo
    
    # Failed Services
    echo "${BOLD}Failed Services:${RESET}"
    systemctl --failed --no-legend 2>/dev/null | sed 's/^/  /' || \
        echo "  No failed services"
    echo
    
    # High Resource Services
    echo "${BOLD}Top 5 Services by Memory Usage:${RESET}"
    ps aux --sort=-%mem | head -6 | awk '{printf "  %-10s %-10s %s\n", $2, $4, $11}' | \
        sed '1s/^/  PID       MEM%      COMMAND\n/'
    echo
}

# ----------------------------------------------------------------------------
# 7. PERFORMANCE METRICS
# ----------------------------------------------------------------------------

report_performance() {
    echo "${BOLD}${ULINE}7. PERFORMANCE METRICS${RESET}"
    echo "==========================="
    
    # Load Average
    echo "${BOLD}System Load:${RESET}"
    uptime | awk -F'load average:' '{print $2}' | sed 's/^/  /'
    echo
    
    # CPU Usage
    echo "${BOLD}CPU Usage:${RESET}"
    top -bn1 | grep "%Cpu" | sed 's/^/  /'
    echo
    
    # Memory Usage Details
    echo "${BOLD}Memory Usage Details:${RESET}"
    free -m | awk 'NR==2{printf "  Used: %s/%s MB (%.1f%%)\n", $3, $2, $3*100/$2}' | sed 's/^/  /'
    free -m | awk 'NR==3{printf "  Swap: %s/%s MB (%.1f%%)\n", $3, $2, $3*100/$2}' | sed 's/^/  /'
    echo
    
    # Disk I/O
    echo "${BOLD}Disk I/O Statistics:${RESET}"
    if command -v iostat &>/dev/null; then
        iostat -d -x 1 1 | tail -n +4 | head -10 | sed 's/^/  /'
    else
        echo "  [iostat not installed]"
    fi
    echo
    
    # Inode Usage
    echo "${BOLD}Inode Usage:${RESET}"
    df -i | grep -E "(Filesystem|/dev/sd|/dev/nvme|/dev/mapper)" | sed 's/^/  /'
    echo
}

# ----------------------------------------------------------------------------
# 8. CLOUD/VM INFORMATION
# ----------------------------------------------------------------------------

report_cloud_vm() {
    echo "${BOLD}${ULINE}8. CLOUD/VIRTUALIZATION INFORMATION${RESET}"
    echo "==========================================="
    
    # Virtualization Detection
    echo "${BOLD}Virtualization Platform:${RESET}"
    if systemd-detect-virt 2>/dev/null | grep -q "none"; then
        echo "  Bare Metal"
    else
        systemd-detect-virt | sed 's/^/  /'
    fi
    echo
    
    # Cloud-init (common in cloud)
    echo "${BOLD}Cloud-init Status:${RESET}"
    if command -v cloud-init &>/dev/null; then
        cloud-init status 2>/dev/null | sed 's/^/  /' || echo "  Not running"
    else
        echo "  Not installed"
    fi
    echo
    
    # DMI Information for Cloud
    echo "${BOLD}DMI System Information:${RESET}"
    if sudo -n true 2>/dev/null && command -v dmidecode &>/dev/null; then
        sudo dmidecode -s system-manufacturer 2>/dev/null | sed 's/^/  Manufacturer: /'
        sudo dmidecode -s system-product-name 2>/dev/null | sed 's/^/  Product Name: /'
    else
        echo "  [Requires sudo/dmidecode]"
    fi
    echo
    
    # CPU Virtualization Flags
    echo "${BOLD}CPU Virtualization Support:${RESET}"
    if grep -q -E "vmx|svm" /proc/cpuinfo; then
        echo "  Hardware virtualization supported"
    else
        echo "  Hardware virtualization NOT supported"
    fi
    echo
}

# ----------------------------------------------------------------------------
# 9. PACKAGE & UPDATE INFORMATION
# ----------------------------------------------------------------------------

report_packages() {
    echo "${BOLD}${ULINE}9. PACKAGE INFORMATION${RESET}"
    echo "=========================="
    
    # Package Counts
    echo "${BOLD}Package Statistics:${RESET}"
    if command -v dpkg &>/dev/null; then
        echo "  Total installed packages: $(dpkg -l | grep -c '^ii')"
        echo "  Pending updates: $(apt list --upgradable 2>/dev/null | grep -c upgradable)"
    fi
    echo
    
    # Snap Packages
    echo "${BOLD}Snap Packages:${RESET}"
    if command -v snap &>/dev/null; then
        snap list 2>/dev/null | head -10 | sed 's/^/  /'
    else
        echo "  Snap not installed"
    fi
    echo
    
    # Last Updates
    echo "${BOLD}Recent Package Changes:${RESET}"
    if [[ -f /var/log/apt/history.log ]]; then
        grep -A 2 "Start-Date:" /var/log/apt/history.log | tail -6 | sed 's/^/  /'
    fi
    echo
    
    # Repository Information
    echo "${BOLD}Repository Configuration:${RESET}"
    ls -la /etc/apt/sources.list.d/ 2>/dev/null | head -10 | sed 's/^/  /' || \
        echo "  No additional repositories configured"
    echo
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

generate_report() {
    local output_file="${OUTPUT_DIR}/system_report_${REPORT_TIMESTAMP}.txt"
    
    log_info "Generating system report..."
    
    {
        generate_header
        report_system_overview
        report_hardware
        report_storage
        report_network
        report_security
        report_services
        report_performance
        report_cloud_vm
        report_packages
    } | tee "$output_file"
    
    # Generate HTML version if requested
    if [[ "${HTML_OUTPUT:-0}" -eq 1 ]]; then
        generate_html_report "$output_file"
    fi
    
    # Generate JSON summary if requested
    if [[ "${JSON_OUTPUT:-0}" -eq 1 ]]; then
        generate_json_summary
    fi
    
    log_success "Report saved to: $output_file"
    echo "File size: $(du -h "$output_file" | cut -f1)"
}

generate_html_report() {
    local txt_file="$1"
    local html_file="${txt_file%.txt}.html"
    
    log_info "Generating HTML report..."
    
    cat <<EOF > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Report - $(hostname) - $(date)</title>
    <style>
        body { font-family: 'Courier New', monospace; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #444; border-left: 5px solid #2196F3; padding-left: 10px; margin-top: 30px; }
        h3 { color: #555; }
        pre { background: #f8f8f8; padding: 15px; border-radius: 5px; border-left: 4px solid #FF9800; overflow-x: auto; }
        .timestamp { color: #666; font-size: 0.9em; }
        .summary { background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .warning { background: #fff3e0; border-left: 4px solid #ff9800; padding: 10px; }
        .critical { background: #ffebee; border-left: 4px solid #f44336; padding: 10px; }
        .success { color: #4CAF50; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 System Information Report</h1>
        <div class="timestamp">Generated: $(date) | Host: $(hostname -f)</div>
        
        <div class="summary">
            <h3>📋 Quick Summary</h3>
            <p><strong>OS:</strong> Ubuntu $(grep '^VERSION=' /etc/os-release | cut -d= -f2 | tr -d '"')</p>
            <p><strong>Kernel:</strong> $(uname -r)</p>
            <p><strong>Uptime:</strong> $(uptime -p | sed 's/up //')</p>
            <p><strong>Load Average:</strong> $(uptime | awk -F'load average:' '{print $2}')</p>
        </div>
        
        <h2>📋 Report Contents</h2>
        <pre>
$(sed -n '1,20p' "$txt_file")
        </pre>
        
        <h2>📄 Full Report</h2>
        <pre>
$(sed 's/</\&lt;/g; s/>/\&gt;/g' "$txt_file")
        </pre>
        
        <div class="timestamp">
            Report ID: ${REPORT_TIMESTAMP} | Generated by ${SCRIPT_NAME} v${SCRIPT_VERSION}
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "HTML report saved to: $html_file"
}

generate_json_summary() {
    local json_file="${OUTPUT_DIR}/system_summary_${REPORT_TIMESTAMP}.json"
    
    log_info "Generating JSON summary..."
    
    cat <<EOF > "$json_file"
{
  "report": {
    "metadata": {
      "generated": "$(date -Iseconds)",
      "hostname": "$(hostname -f)",
      "script": "${SCRIPT_NAME}",
      "version": "${SCRIPT_VERSION}",
      "report_id": "${REPORT_TIMESTAMP}"
    },
    "system": {
      "os": "$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')",
      "kernel": "$(uname -r)",
      "architecture": "$(uname -m)",
      "uptime": "$(uptime -p | sed 's/up //')"
    },
    "hardware": {
      "cpu_cores": $(nproc),
      "cpu_model": "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')",
      "memory_total_mb": $(free -m | awk '/^Mem:/ {print $2}'),
      "memory_used_mb": $(free -m | awk '/^Mem:/ {print $3}'),
      "swap_total_mb": $(free -m | awk '/^Swap:/ {print $2}')
    },
    "storage": {
      "disks": [
EOF
    
    # Add disk information
    df -h --type=ext4 --type=xfs --type=btrfs --output=source,fstype,size,used,avail,pcent 2>/dev/null | \
        tail -n +2 | while read -r line; do
        IFS=' ' read -r source fstype size used avail pcent <<< "$line"
        cat <<EOF >> "$json_file"
        {
          "source": "$source",
          "filesystem": "$fstype",
          "size": "$size",
          "used": "$used",
          "available": "$avail",
          "usage_percent": "$pcent"
        },
EOF
    done | sed '$ s/,$//' >> "$json_file"
    
    cat <<EOF >> "$json_file"
      ]
    },
    "network": {
      "interfaces": [
EOF
    
    # Add network interface information
    ip -j addr show 2>/dev/null | jq -r '.[] | "        {\"name\": \"\(.ifname)\", \"mac\": \"\(.address)\", \"ipv4\": [\(.addr_info[] | select(.family == \"inet\") | .local | \"\\\"\" + . + \"\\\"\")], \"ipv6\": [\(.addr_info[] | select(.family == \"inet6\") | .local | \"\\\"\" + . + \"\\\"\")]},"' 2>/dev/null | \
        sed '$ s/,$//' >> "$json_file" || echo "      ]" >> "$json_file"
    
    cat <<EOF >> "$json_file"
      ]
    },
    "security": {
      "ssh_root_login": "$(grep -i "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | tail -1 | cut -d' ' -f2 || echo "unknown")",
      "firewall_active": "$(if command -v ufw &>/dev/null; then sudo ufw status 2>/dev/null | grep -q "active" && echo "true" || echo "false"; else echo "unknown"; fi)"
    }
  }
}
EOF
    
    log_success "JSON summary saved to: $json_file"
}

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_help() {
    cat <<EOF
${BOLD}${SCRIPT_NAME} - Professional System Information Reporter${RESET}
Version: ${SCRIPT_VERSION}

${ULINE}Usage:${RESET}
  ${SCRIPT_NAME} [OPTIONS]

${ULINE}Options:${RESET}
  -h, --help          Show this help message
  -v, --version       Show version information
  -q, --quiet         Quiet mode (minimal output)
  --html              Generate HTML report alongside text
  --json              Generate JSON summary
  --force             Force run on non-Ubuntu 24.04 systems
  --output DIR        Specify custom output directory
  --no-color          Disable colored output
  --sections LIST     Comma-separated list of sections to include
                      (overview,hardware,storage,network,security,
                       services,performance,cloud,packages)

${ULINE}Examples:${RESET}
  ${SCRIPT_NAME}                     # Full report (default)
  ${SCRIPT_NAME} --html --json       # Multiple formats
  ${SCRIPT_NAME} --sections hardware,network  # Specific sections only
  ${SCRIPT_NAME} --output /var/reports  # Custom output directory

${ULINE}Description:${RESET}
  Generates comprehensive system information reports for Ubuntu 24.04.
  Reports include hardware, storage, network, security, services,
  performance metrics, and more.

${ULINE}Exit Codes:${RESET}
  0   Success
  1   General error
  2   Invalid argument
  3   Environment validation failed
  4   Permission denied

${ULINE}Files:${RESET}
  Output directory: ${OUTPUT_DIR}
  Log file: ${LOG_FILE}
EOF
}

show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "Ubuntu 24.04 System Information Reporter"
    echo "License: MIT"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    local sections="all"
    local quiet_mode=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -q|--quiet)
                quiet_mode=1
                ;;
            --html)
                HTML_OUTPUT=1
                ;;
            --json)
                JSON_OUTPUT=1
                ;;
            --force)
                FORCE=1
                ;;
            --output)
                OUTPUT_DIR="$2"
                shift
                ;;
            --no-color)
                # Colors are already disabled if not a tty
                ;;
            --sections)
                sections="$2"
                shift
                ;;
            *)
                echo "${RED}Error: Unknown option '$1'${RESET}" >&2
                show_help
                exit 2
                ;;
        esac
        shift
    done
    
    # Check for root privileges for certain sections
    if [[ $EUID -eq 0 ]]; then
        log_info "Running with root privileges"
    else
        log_warning "Running without root privileges - some information may be limited"
    fi
    
    # Validate environment
    validate_environment || exit 3
    
    # Generate report
    if [[ $quiet_mode -eq 1 ]]; then
        generate_report >/dev/null
    else
        echo "${BOLD}${GREEN}🚀 Starting System Information Report Generation${RESET}" >&2
        echo "${DIM}Report will be saved to: ${OUTPUT_DIR}${RESET}" >&2
        echo
        
        generate_report
        
        echo
        echo "${BOLD}${GREEN}✅ Report generation completed successfully${RESET}" >&2
        echo "${DIM}Check ${OUTPUT_DIR} for output files${RESET}" >&2
    fi
    
    exit 0
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Trap signals for clean exit
trap 'log_error "Script interrupted by user"; exit 130' SIGINT SIGTERM

# Run main function
main "$@"