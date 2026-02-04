#!/usr/bin/env bash

set -euo pipefail
#set -x

# ##################################################### #
# ################   CONFIGURATION   ################## #
# ##################################################### #

# ------------------------ #
# --- GLOBAL VARIABLES --- #
# ------------------------ #

### Colors for output ###
RED=$(tput setaf 1)         # Red
GREEN=$(tput setaf 2)       # Green
YELLOW=$(tput setaf 3)      # Yellow
BLUE=$(tput setaf 4)        # Blue
MAGENTA=$(tput setaf 5)     # Magenta
CYAN=$(tput setaf 6)        # Cyan
NC=$(tput sgr0)             # Reset

### Default action ###
ACTION="${1:-install}"

CONFLICTING_PACKGES=( 
    "docker.io" 
    "docker-doc" 
    "docker-compose" 
    "docker-compose-v2" 
    "podman-docker" 
    "containerd" 
    "runc" 
)

DOCKER_PACKAGES=(
    "docker-ce"
    "docker-ce-cli"
    "containerd.io"
    "docker-buildx-plugin"
    "docker-compose-plugin"
    "docker-ce-rootless-extras"
)

DEPENDENCIES=(
    "curl"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "software-properties-common"
)

DOCKER_SERVICES=(
    "docker" 
    "docker.socket" 
    "containerd" 
    "docker-compose"
)

DOCKER_FOLDERS=( 
    "/etc/docker" 
    "/etc/containerd" 
    "/var/lib/docker" 
    "/var/lib/containerd" 
    "/var/run/docker"
    "/var/run/containerd"
    "${HOME}/.docker"
)
# ------------------------- #
# --- LOGGING FUNCTIONS --- #
# ------------------------- #
function log_info() {
    printf "%s %s\n" "${BLUE}[INFO]${NC}" "$1"
}
function log_success() {
    printf "%s %s\n" "${GREEN}[SUCCESS]${NC}" "$1"
}
function log_warning() {
    printf "%s %s\n" "${YELLOW}[WARNING]${NC}" "$1"
}
function log_error() {
    printf "%s %s\n" "${RED}[ERROR]${NC}" "$1"
}
function log_h1() {
    printf "\n%s\n" "${MAGENTA}=== $1 ===${NC}"
}
function log_h2() {
    printf "\n%s\n" "${CYAN}--- $1 ---${NC}"
}


# ##################################################### #
# #############   HELPER FUNCTIONS   ################## #
# ##################################################### #

# ----------------------------------------------------- #
# Check user is root (no args)
# ----------------------------------------------------- #
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use sudo."
        exit 1
    fi
}

# ----------------------------------------------------- #
# Check OS prerequisites (no args)
# ----------------------------------------------------- #
function check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "This script is for Ubuntu only."
        exit 1
    fi
    
    source /etc/os-release

    if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "24.04" ]]; then
        log_warning "This script is tested on Ubuntu 24.04. You're running $NAME $VERSION_ID"
    fi
}

# ----------------------------------------------------- #
# Check if repo is installed (string input)
# ----------------------------------------------------- #
function is_repo_installed() {
    local repo_name="$1"
    apt-cache policy | grep -q "${repo_name}"
    return $?  
}

# ----------------------------------------------------- #
#  Check if package is installed
#  (string input / returns 0 if installed)
# ----------------------------------------------------- #
function is_pkg_installed() {
    local package_name="${1}"
    dpkg-query --list | grep "^ii\s*${package_name}" &>/dev/null
    return $?
}

# ----------------------------------------------------- #
#  Install a single package
#  (string input / verbose output)
# ----------------------------------------------------- #
function pkg_install() {
    local pkg="${1}"
    if [[ $(is_pkg_installed "${pkg}") != 0 ]]; then
        log_info "Package ${pkg} is not installed. Installing..."
            if ! apt-get --yes --no-install-recommends install "${pkg}" ; then
                log_error "Error installing ${pkg}"
            fi
    else
        log_warning "Package ${pkg} is already installed. Skipping!"
    fi

    log_success "Installation of ${pkg} complete."
}

# ----------------------------------------------------- #
#  Install a list of packages
#  (array input / quiet loop & verbocity by pkg_install)
# ----------------------------------------------------- #
function pkgList_install() {
    local list=("$@")
    for pkg in "${list[@]}"; do
        pkg_install "${pkg}"
    done
}

# ----------------------------------------------------- #
#  Remove (apt) a single package
#  (string input / verbose output)
# ----------------------------------------------------- #
function pkg_rm() {
	local pkg="${1}"
    if [[ $(is_pkg_installed "${pkg}") == 0 ]]; then
        log_info "Package ${pkg} is installed. Removing..."
        apt-get --purge remove --yes "${pkg}" || true
        #apt-get autoremove --yes || true
        if [[ $(is_pkg_installed "${pkg}") == 0 ]]; then
            log_error "Error removing ${pkg}"
        else
            log_success "Package ${pkg} removed successfully."
        fi
    else
        log_warning "Package ${pkg} is not installed.Skipping!"
    fi
}

# ----------------------------------------------------- #
#  Remove a list of packages 
#  (array input / quiet loop & verbocity by pkg_rm)
# ----------------------------------------------------- #
function pkgList_rm() {
    local list=("$@")
    for pkg in "${list[@]}"; do
        pkg_rm "${pkg}"
    done
}

# ----------------------------------------------------- #
#  FOLDER Remove with confirmation
#  (string input / verbose output)
# ----------------------------------------------------- #
function folder_rm() {
    local folder="${1}"
    if [[ -d "${folder}" ]]; then
        log_info "Folder ${folder} found. Deleting ..."
        rm -rf "${folder}"
        if [[ ! -d "$folder" ]]; then
            log_success "Folder and its contents have been deleted: ${folder}"
        else
            log_error "Failed to delete folder ${folder}"
        fi
    else
        log_warning "Folder does not exist: ${folder}. Skipping!"
    fi
}

# ----------------------------------------------------- #
#  FILE Remove with confirmation
#  (string input / verbose output)
# ----------------------------------------------------- #
function file_rm() {
    local file="${1}"
    if [[ -f "${file}" ]]; then
        log_info "File ${file} found. Deleting ..."
        rm -f "${file}"
        if [[ ! -f "$file" ]]; then
            log_success "File has been deleted: ${file}"
        else
            log_error "Failed to delete file: ${file}"
        fi
    else
        log_warning "File does not exist" "${file}"
    fi
}

# ----------------------------------------------------- #
#  GET STATUS for a list of services
#  (array input / verbose output)
# ----------------------------------------------------- #
function showStatus_services() {
    local -n services_ref="$1"

    log_info "Checking status of ${#services_ref[@]} systemd units..."
    printf "%-25s %-10s %-10s %-10s\n" "SERVICE" "STARTED" "ENABLED" "MASKED"
    printf "%-25s %-10s %-10s %-10s\n" "-------" "-------" "-------" "------"

    for unit in "${services_ref[@]}"; do
        systemctl is-active --quiet "${unit}" && started=yes || started=no

        state=$(systemctl is-enabled "${unit}" 2>/dev/null || echo unknown)
        enabled=$([[ $state == enabled ]] && echo yes || echo no)
        masked=$([[ $state == masked ]] && echo yes || echo no)

        printf "%-25s %-10s %-10s %-10s\n" "${unit}" "${started}" "${enabled}" "${masked}"
  done
}

# ----------------------------------------------------- #
#  STOP & DISABLE & MASK a list of services
#  (array input / verbose output)
# ----------------------------------------------------- #
function stopDisableMask_services() {
  local -n services_ref="$1"

  log_info "Processing ${#services_ref[@]} systemd units..."

  for unit in "${services_ref[@]}"; do
    log_info "---- $unit ----"

    # Check existence
    if ! systemctl list-unit-files --no-legend | awk '{print $1}' | grep -qx "$unit"; then
      log_warning "$unit not found, skipping."
      continue
    fi

    # Initial status
    is_active=$(systemctl is-active "$unit" 2>/dev/null || true)
    is_enabled=$(systemctl is-enabled "$unit" 2>/dev/null || true)

    if systemctl is-enabled "$unit" 2>/dev/null | grep -q masked; then
      is_masked="yes"
    else
      is_masked="no"
    fi

    log_info "Initial state: active=$is_active, enabled=$is_enabled, masked=$is_masked"

    # Stop
    if [ "$is_active" = "active" ]; then
      if systemctl stop "$unit"; then
        log_success "Stopped successfully."
      else
        log_error "Failed to stop."
      fi
    else
      log_info "Not running; skip stop."
    fi

    # Disable
    if [ "$is_enabled" = "enabled" ]; then
      if systemctl disable "$unit"; then
        log_success "Disabled successfully."
      else
        log_error "Failed to disable."
      fi
    else
      log_info "Already disabled."
    fi

    # Mask
    if [ "$is_masked" = "no" ]; then
      if systemctl mask "$unit"; then
        log_success "Masked successfully."
      else
        log_error "Failed to mask."
      fi
    else
      log_info "Already masked."
    fi
  done
}

# ----------------------------------------------------- #
#  UNMASK & ENABLE & START a list of services
#  (array input / verbose output)
# ----------------------------------------------------- #
function unmaskEnableStart_services() {
  local -n services_ref="$1"

  log_info "Processing ${#services_ref[@]} systemd units..."

  for unit in "${services_ref[@]}"; do
    log_info "---- $unit ----"

    # Check existence
    if ! systemctl list-unit-files --no-legend | awk '{print $1}' | grep -qx "$unit"; then
      log_warn "$unit not found, skipping."
      continue
    fi

    # Initial status
    is_active=$(systemctl is-active "$unit" 2>/dev/null || true)
    is_enabled=$(systemctl is-enabled "$unit" 2>/dev/null || true)

    if systemctl is-enabled "$unit" 2>/dev/null | grep -q masked; then
      is_masked="yes"
    else
      is_masked="no"
    fi

    log_info "Initial state: active=$is_active, enabled=$is_enabled, masked=$is_masked"

    # Unmask
    if [ "$is_masked" = "yes" ]; then
      if systemctl unmask "$unit"; then
        log_success "Unmasked successfully."
      else
        log_error "Failed to unmask."
        continue
      fi
    else
      log_info "Not masked; skip unmask."
    fi

    # Enable
    if [ "$is_enabled" != "enabled" ]; then
      if systemctl enable "$unit"; then
        log_success "Enabled successfully."
      else
        log_error "Failed to enable."
      fi
    else
      log_info "Already enabled."
    fi

    # Start
    if [ "$is_active" != "active" ]; then
      if systemctl start "$unit"; then
        log_success "Started successfully."
      else
        log_error "Failed to start."
      fi
    else
      log_info "Already running."
    fi
  done
}


# ##################################################### #
# #############   SCRIPT LOGIC FUNCTIONS   ############ #
# ##################################################### #

# ----------------------------------------------------- #
#  UNINSTALL Docker and cleanup
#  (no args / verbose output)
# ----------------------------------------------------- #
function uninstall_docker() {

    # Confirm uninstallation
    log_warning "This will completely remove Docker and all related data!"
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled."
        exit 0
    fi
    
    # Start uninstallation
    log_info "Starting Docker uninstallation..."

    #TODO: Improve
    # Leave Swarm if part of one
    if docker node ls > /dev/null 2>&1; then
        log_info "Leaving Swarm cluster..."
        if docker swarm leave --force; then
            log_success "Left Swarm cluster."
        else
            log_warning "Failed to leave Swarm cluster. Continuing uninstall..."
        fi
    fi
    
    # Stop Docker services
    stopDisableMask_services DOCKER_SERVICES
    
    # Remove Docker packages
    log_info "Removing Docker packages..."
    pkgList_rm "${DOCKER_PACKAGES[@]}"

    # Remove conflicting packages (if any remain)
    log_info "Removing conflicting packages (if any)..."
    pkgList_rm "${CONFLICTING_PACKGES[@]}"
    # Clean up apt
    apt-get autoremove -y && apt-get autoclean && apt-get clean && apt-get update
    
    # Remove Docker data and configuration
    log_info "Removing Docker data and configuration..."
    for folder in "${DOCKER_FOLDERS[@]}"; do
        folder_rm "$folder"
    done

    # Remove old Docker repository and keyrings (if any)
    SEARCH_DIRS=( "/etc/apt/sources.list.d" "/etc/apt/keyrings" )
    docker_matches=()
    for dir in "${SEARCH_DIRS[@]}"; do
        mapfile -d '' -t found < <(
            find "$dir" \( -type f -o -type s \) -iname '*docker*' -print0
        )
        docker_matches+=( "${found[@]}" )
    done
    file_rm "${docker_matches[@]}"

    # Remove Docker socket if exists
    [[ -S /var/run/docker.sock ]] && rm /var/run/docker.sock && log_success "Removed old Docker socket."
    
    # Remove Docker group
    log_info "Removing Docker group..."
    if getent group docker > /dev/null; then
        groupdel docker 2>/dev/null || true
    fi

    # Docker group removal with logging
    getent group docker >/dev/null \
        && { groupdel docker >/dev/null 2>&1 && log_success "docker group removed"; } \
        || log_warning "docker group already absent or could not be removed"

    log_success "Docker has been completely removed and cleaned up!"
}

# ----------------------------------------------------- #
#  INSTALL Docker from official repository (no args)
# ----------------------------------------------------- #
function install_docker() {

    # Confirm installation
    log_warning "This will install Docker ecosystem on your machine."
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled."
        exit 0
    fi

    # Install dependencies
    log_h2 "Installing dependencies for Docker..."
    pkgList_install "${DEPENDENCIES[@]}"

    # Install docker by official get-docker script (not for production use)
    # log_info "Downloading and running Docker installation script..."
    # curl -fsSL https://get.docker.com -o get-docker.sh
    # sh get-docker.sh
    # rm get-docker.sh

    # Add Docker's official GPG key:
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    printf '%s\n'   "Types: deb" \
                    "URIs: https://download.docker.com/linux/ubuntu" \
                    "Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")" \
                    "Components: stable" \
                    "Signed-By: /etc/apt/keyrings/docker.asc" \
    >>/etc/apt/sources.list.d/docker.sources


    # Install Docker components
    log_info "Installing Docker components..."
    apt-get update
    pkgList_install "${DOCKER_PACKAGES[@]}"
    
    # ----------------------- #
    # Post-installation steps
    # ----------------------- #

    # Start and enable Docker
    log_info "Starting Docker service..."
    systemctl start docker
    systemctl enable docker
    
    # Test Docker installation
    log_info "Testing Docker installation..."
    if docker --version && docker run hello-world; then
        log_success "Docker installed successfully!"
    else
        log_error "Docker installation test failed!"
        exit 1
    fi
    
    # Install Docker Swarm (already included in Docker CE)
    log_info "Docker Swarm is included in Docker CE. No separate installation needed."
    
    #TODO: Improve
    # Show Swarm status
    # log_info "Checking Docker Swarm status..."
    # if docker node ls > /dev/null 2>&1; then
    #     log_info "This node is already part of a Swarm cluster."
    #     docker node ls
    # else
    #     log_info "This node is not part of a Swarm cluster yet."
    #     log_info "To initialize a Swarm cluster, run: docker swarm init"
    #     log_info "To join an existing Swarm, run: docker swarm join --token <token> <manager-ip>:2377"
    # fi
    
    # Post-installation - allow non-root user to run Docker (optional)
    log_info "Would you like to allow a non-root user to run Docker commands?"
    read -p "Enter username (leave empty to skip): " DOCKER_USER
    if [[ -n "$DOCKER_USER" ]]; then
        if id "$DOCKER_USER" &>/dev/null; then
            usermod -aG docker "$DOCKER_USER"
            log_success "User $DOCKER_USER added to docker group."
            log_warning "User needs to log out and back in for changes to take effect."
        else
            log_error "User $DOCKER_USER does not exist."
        fi
    fi
}

# ----------------------------------------------------- #
#  DOCKER SWARM INITIALIZATION (no args)
# ----------------------------------------------------- #
function init_swarm() {
    log_info "Initializing Docker Swarm..."
    #TODO: Check & Improve
    if docker node ls > /dev/null 2>&1; then
        log_warning "This node is already part of a Swarm cluster."
        return
    fi
    
    # Get the primary IP address
    PRIMARY_IP=$(ip route get 1 | awk '{print $7; exit}')
    log_info "Detected IP address: $PRIMARY_IP"
    
    read -p "Enter the IP address to advertise for Swarm [default: $PRIMARY_IP]: " SWARM_ADVERTISE_ADDR
    SWARM_ADVERTISE_ADDR=${SWARM_ADVERTISE_ADDR:-$PRIMARY_IP}
    
    if docker swarm init --advertise-addr "$SWARM_ADVERTISE_ADDR"; then
        log_success "Docker Swarm initialized successfully!"
        
        # Show the join tokens
        log_info "Manager token for other nodes to join as managers:"
        docker swarm join-token manager -q
        log_info "Worker token for other nodes to join as workers:"
        docker swarm join-token worker -q
        
        log_info "To add a manager node: docker swarm join --token <manager-token> $SWARM_ADVERTISE_ADDR:2377"
        log_info "To add a worker node: docker swarm join --token <worker-token> $SWARM_ADVERTISE_ADDR:2377"
    else
        log_error "Failed to initialize Docker Swarm!"
        exit 1
    fi
}

# ----------------------------------------------------- #
#  GET DOCKER STATUS
#  (no args / verbose output)
# ----------------------------------------------------- #
function docker_status() {
    log_h1 "=== Docker Status ==="
    #TODO: Improve
    # Check if Docker is installed
    if command -v docker &> /dev/null; then
        log_success "Docker is installed"
        docker --version
        
        # Check Docker Swarm status
        log_h2 "=== Docker Swarm Status ==="
        if docker node ls > /dev/null 2>&1; then
            log_success "This node is part of a Swarm cluster"
            log_info "Nodes in the cluster:"
            docker node ls
        else
            log_info "This node is NOT part of a Swarm cluster"
        fi
        
        # Show Docker info
        log_h2 "Docker Info"
        docker info --format '{{json .}}' | jq -r '. | {
            "Containers": .Containers,
            "Running": .ContainersRunning,
            "Paused": .ContainersPaused,
            "Stopped": .ContainersStopped,
            "Images": .Images,
            "Swarm": .Swarm.LocalNodeState,
            "NodeID": .Swarm.NodeID[:12]
        }' 2>/dev/null || docker info | grep -E "(Containers|Images|Swarm|NodeID)"
        
    else
        log_error "Docker is not installed"
    fi

    # Check Docker service status
    log_h2 "Docker Service Status"
    showStatus_services DOCKER_SERVICES
    
    # Check if Docker repository is configured
    log_h2 "Repository Status"
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        log_success "Docker repository is configured"
    else
        log_info "Docker repository is not configured"
    fi

    if [[ $(is_repo_installed "download.docker.com") ]]; then
        log_success "Docker repository is configured (apt_cache)"
    else
        log_info "Docker repository is not configured (apt_cache)"
    fi

    # Check for Docker packages
    log_h2 "Docker Packages Installed"
    for pkg in "${DOCKER_PACKAGES[@]}"; do
        if is_pkg_installed "$pkg"; then
            log_success "Package $pkg is installed"
        else
            log_info "Package $pkg is NOT installed"
        fi
    done

    # Check for Docker files and folders
    log_h2 "Docker Files and Folders"
    for folder in "${DOCKER_FOLDERS[@]}"; do
        if [[ -e "$folder" ]]; then
            log_success "Exists: $folder"
        else
            log_info "Not found: $folder"
        fi
    done

    # Check for Docker group
    log_h2 "Docker Group and User"
    if getent group docker > /dev/null; then
        log_success "Docker group exists"
    else
        log_info "Docker group does not exist"
    fi

    # Check current user in docker group
    log_info "Current User Docker Group Membership"
    if id -nG "$SUDO_USER" | grep -qw "docker"; then
        log_success "User $SUDO_USER is in docker group"
    else
        log_info "User $SUDO_USER is NOT in docker group"
    fi

    # Check Docker socket
    log_info "Docker Socket"
    if [[ -S /var/run/docker.sock ]]; then
        log_success "Docker socket exists"
    else
        log_info "Docker socket does not exist"
    fi
}

# ------------------------- #
# --- SCRIPT USAGE HELP --- #
# ------------------------- #
function show_help() {
    local script_name
    script_name="$(basename "${BASH_SOURCE[0]:-$0}")"
    
printf '%s\n' "
Usage: sudo ./${script_name} [COMMAND]
        
  COMMANDS:
    install      Install Docker and Docker Swarm (default)
    init         Initialize Docker Swarm cluster
    uninstall    Completely remove Docker and cleanup
    status       Show Docker and Swarm status
    help         Show this help message

  EXAMPLES:
    sudo ./${script_name} install      # Install Docker
    sudo ./${script_name} init         # Initialize Swarm cluster
    sudo ./${script_name} uninstall    # Remove Docker completely
    sudo ./${script_name} status       # Check Docker status

  NOTES:
    - Docker Swarm is included in Docker CE
    - Non-root users can be added to 'docker' group
    - Uninstall removes all Docker data and configuration

  DESCRIPTION:
    This script manages Docker and Docker Swarm installation,
    uninstallation, initialization, and status checking on Ubuntu systems.
    "
}

# ##################################################### #
# ###################   MAIN SCRIPT   ################# #
# ##################################################### #
function main() {
    check_root
    check_ubuntu_version
    
    case "$ACTION" in
        install)
            install_docker
            ;;
        init)
            if ! command -v docker &> /dev/null; then
                log_error "Docker is not installed. Run with 'install' first."
                exit 1
            fi
            init_swarm
            ;;
        uninstall|remove|purge)
            uninstall_docker
            ;;
        status)
            docker_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown action: $ACTION"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"