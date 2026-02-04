
# 1. DELL SPECIFIC - Hardware Management
sudo apt install -y \
    openmanage    # Dell OpenManage Server Administrator (OMSA) - CRITICAL
    ipmitool      # IPMI/BMC management
    dmidecode     # DMI table decoder for hardware info
    lshw          # Hardware lister
    smartmontools # SMART disk monitoring
    edac-utils    # Error detection and correction
    nvme-cli      # NVMe drive management

# 3. System Monitoring Essentials
sudo apt install -y \
    htop          # Interactive process viewer (better than top)
    iotop         # I/O monitoring
    iftop         # Network bandwidth monitoring
    nethogs       # Per-process network usage
    bmon          # Network bandwidth monitor
    nmon          # AIX-style system monitor
    dstat         # Versatile resource statistics
    sysstat       # System performance tools (sar, iostat, mpstat)
    atop          # Advanced system & process monitor
    netdata       # Real-time performance monitoring (consider for production)
    strace
    psmisc
    procps
    lsof
    tree

# 4. Disk & Filesystem Tools
sudo apt install -y \
    ncdu          # NCurses disk usage
    duf           # Better df alternative
    f3            # Flash drive testing
    badblocks     # Block device testing
    e2fsprogs     # ext2/3/4 filesystem utilities
    xfsprogs      # XFS filesystem utilities
    btrfs-progs   # BTRFS filesystem utilities
    nfs-common    # NFS client tools
    cifs-utils    # CIFS/SMB client
    sdparm        # SCSI/SATA device parameters
    parted        # Partition editor
    gdisk         # GPT partition editor
    testdisk      # Partition recovery
    lvm2 
    mdadm

# 5. Modern Networking (replace net-tools)
sudo apt install -y \
    iproute2      # Modern networking suite (ip, ss, tc, etc.)
    nftables      # Modern firewall (replaces iptables)
    conntrack     # Netfilter connection tracking
    tcpdump       # Network packet analyzer
    wireshark-common # Protocol analyzer
    mtr-tiny      # Network diagnostic tool
    traceroute    # Trace network route
    iperf3        # Network performance testing
    ethtool       # Ethernet device settings
    net-tools     # ONLY for legacy scripts (if absolutely needed)
    dnsutils      # DNS tools (dig, nslookup)
    whois         # WHOIS client
    nmap          # Network discovery/security scanner
    openssh-server  # SSH server (if not already installed)
    bridge-utils    # Still required for classic Linux bridges. Especially relevant for VMs, containers, KVM, labs.

# 6. Security & Auditing
sudo apt install -y \
    aide          # File integrity checker
    rkhunter      # Rootkit hunter
    chkrootkit    # Rootkit detector
    #auditd        # Linux audit daemon
    fail2ban      # Ban IPs after failed attempts
    ufw           # Uncomplicated firewall
    #apparmor-utils # AppArmor utilities
    #lynis         # Security auditing tool

# 7. Server Management
sudo apt install -y \


# 8. Logging & Analysis
sudo apt install -y \
    logrotate     # Log rotation utility
    lnav          # Log file navigator
    multitail     # Tail multiple files
    goaccess      # Real-time web log analyzer
    syslog-ng     # Enhanced syslog
    journalctl    # Systemd journal (already included)
    rsyslog       # needed for log forwarding; expected by many compliance tools

# 9. Production & High Availability
sudo apt install -y \
    keepalived    # IP failover
    haproxy       # Load balancer
    pacemaker     # Cluster resource manager
    corosync      # Cluster engine
    drbd-utils    # Distributed replicated block device
    glusterfs-client # GlusterFS client
    ceph-common   # Ceph storage client
    zfsutils-linux # ZFS filesystem
    snapd         # Snap package manager
    cockpit       # Web-based admin interface (optional GUI)
    webmin        # Web-based system admin (alternative)

# 10. Dell PowerEdge R630 Specific
# Download these from Dell Support:
# - Dell System Update (DSU) - Unified firmware updater
# - Dell OpenManage Server Administrator (OMSA)
# - Dell OpenManage Enterprise
# - Dell Repository Manager (DRM)

# Install Dell repositories:
wget -qO - https://linux.dell.com/repo/hardware/dsu/bootstrap.cgi | bash
wget -qO - https://linux.dell.com/repo/hardware/omsa/bootstrap.cgi | bash

# Then install:
sudo apt install -y \
    dell-system-update \
    srvadmin-all  # Complete OMSA suite