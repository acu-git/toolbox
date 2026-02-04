#!/bin/bash
# install-essentials.sh for Dell PowerEdge R630 with Ubuntu 24.04 Minimal
set -eo pipefail

# Update first
sudo apt update && sudo apt upgrade -y

#TODO: Implement an installation function with logging and error handling
install_packages() {
  local pkgs=("$@")
  local pkg init_status final_status version

  # Enable colors only if stdout is a TTY
  if [[ -t 1 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    BLUE=$'\e[34m'
    RESET=$'\e[0m'
  else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
  fi

  printf "%-30s %-22s %-10s %-20s\n" "PACKAGE" "INITIAL_STATUS" "FINAL" "VERSION"
  printf "%-30s %-22s %-10s %-20s\n" "-------" "--------------" "-----" "-------"

  for pkg in "${pkgs[@]}"; do
    init_status=""
    final_status="${RED}NOK${RESET}"
    version="-"

    if dpkg -s "$pkg" &>/dev/null; then
      init_status="${YELLOW}already installed${RESET}"
    else
      if apt-cache show "$pkg" &>/dev/null; then
        init_status="${BLUE}available${RESET}"
        if ! apt-get install -y "$pkg" &>/dev/null; then
          printf "%-30s %-22b %-10b %-20s\n" \
            "$pkg" "$init_status" "$final_status" "$version"
          continue
        fi
      else
        init_status="${RED}not available${RESET}"
        printf "%-30s %-22b %-10b %-20s\n" \
          "$pkg" "$init_status" "$final_status" "$version"
        continue
      fi
    fi

    if dpkg -s "$pkg" &>/dev/null; then
      final_status="${GREEN}OK${RESET}"
      version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
    fi

    printf "%-30s %-22b %-10b %-20s\n" \
      "$pkg" "$init_status" "$final_status" "$version"
  done
}


#################################################
###       Core System Utilities Packages      ###
#################################################
core_pkgs=(
    ca-certificates # SSL/TLS/HTTPS certificates
    gnupg           # GNU Privacy Guard for package verification
    software-properties-common  # Manage software sources
    bash-completion # Command line completion for bash
    unzip         # File uncompression utility
    zip           # File compression utility
    lsb-release   # Linux Standard Base information
    vim           # Advanced text editor
    curl          # URL transfer utility
    wget          # Non-interactive network downloader
    rsync         # Fast file transfer
    git           # Version control
    python3-pip   # Python package manager
    jq            # JSON processor
    yq            # YAML processor (like jq for YAML)
    csvkit        # CSV utilities
    xmlstarlet    # XML utilities
)
# apt install -y "${core_pkgs[@]}"
install_packages "${core_pkgs[@]}"

#################################################
###    HW Management & Monitoring Packages    ###
#################################################
hw_pkgs=(
    lm-sensors    # Hardware monitoring
    smartmontools # SMART disk monitoring
    ipmitool      # IPMI management (Dell iDRAC)
    dmidecode     # DMI table decoder
    lshw          # List hardware
)
# apt install -y "${hw_pkgs[@]}"
install_packages "${hw_pkgs[@]}"

#################################################
###            System Tools Packages          ###
#################################################
sys_pkgs=(
    htop         # Interactive process viewer
    iotop        # I/O usage monitor
    sysstat      # System performance tools
    atop         # Advanced system and process monitor
    ncdu         # Disk usage analyzer
    duf          # Disk usage utility
    auditd       # Linux Auditing System
    lsof         # List open files
    parted       # Disk partitioning tool
    lnav         # Log file navigator
    logrotate    # Log file rotation utility
)
# apt install -y "${sys_pkgs[@]}"
install_packages "${sys_pkgs[@]}"

#################################################
###           Security Tools Packages         ###
#################################################
sec_pkgs=(
    ufw          # Uncomplicated Firewall
    fail2ban     # Intrusion prevention software
    lynis        # Security auditing tool
)
# apt install -y "${sec_pkgs[@]}"
install_packages "${sec_pkgs[@]}"

#################################################
###           Network Tools Packages          ###
#################################################
net_pkgs=(
    iptables     # Packet filtering framework
    tcpdump      # Network packet analyzer
    dnsutils     # DNS utilities (dig, nslookup)
    traceroute   # Network path tracing tool
    ethtool      # Ethernet device settings
    nmap         # Network scanner
    netcat       # Network utility for reading/writing to network connections
    nethogs      # Network traffic monitor
    iperf3       # Network performance measurement tool
)
# apt install -y "${net_pkgs[@]}"
install_packages "${net_pkgs[@]}"

#################################################
###           Dell Specific Packages          ###
#################################################
    # TODO: Add Dell repository / convert from rpm and install
    # openmanage
