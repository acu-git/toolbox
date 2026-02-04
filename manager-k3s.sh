#!/usr/bin/env bash

set -euo pipefail
# set -x

############################
# Configuration Parameters #
############################
#TODO: uniformize variables usage across script
K3S_VERSION=""              # Leave empty for latest stable, or set e.g. "v1.29.1+k3s1"
K3S_NODE_NAME="$(hostname)"
K3S_CLUSTER_CIDR="10.32.0.0/16"
K3S_SERVICE_CIDR="10.33.0.0/16"
K3S_DISABLE_COMPONENTS="traefik,servicelb"
K3S_KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"
# K3S_URL=https://<server-ip>:6443  # Uncomment and set for agent nodes
# K3S_TOKEN=<node-token>            # Uncomment and set for agent nodes

K3S_PROFILE_FILE="/etc/profile.d/k3s.sh"

#TODO: check which one will be part of base image
DEPENDENCIES=(
  curl
  ca-certificates
  apt-transport-https
  gnupg
  iptables
  jq
  bash-completion
)


############################
# Helper Functions         #
############################

#TODO: elaborate logging functions
#### Logging ####
log() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

#### Pre-flight Checks ####
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
  fi
}

require_ubuntu() {
  
  if ! grep -qi ubuntu /etc/os-release; then
    error "This script is intended for Ubuntu only (detected: ${ID:-unknown})." >&2
    exit 1
  fi

  UBUNTU_VERSION="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')"

  if [ "$UBUNTU_VERSION" != "24.04" ]; then
      log "Warning: Detected Ubuntu ${UBUNTU_VERSION:-unknown}. Script is validated for 24.04."
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

######################
# Install K3S & Helm #
######################

install_k3s() {
    log "Starting K3s installation..."

    #### System Preparation ####
    log "Disabling swap..."
    swapoff -a
    sed -i.bak '/ swap / s/^/#/' /etc/fstab

    log "Updating system packages..."
    apt update -y && apt upgrade -y
    
    log "Installing required dependencies..."
    apt install -y "${DEPENDENCIES[@]}"

    #### Kernel Modules & Sysctl ####
    log "Loading required kernel modules..."
    printf '%s\n' "br_netfilter" "overlay" > /etc/modules-load.d/k3s.conf

    modprobe br_netfilter
    modprobe overlay

    log "Applying sysctl settings..."
    printf '%s\n'   "net.bridge.bridge-nf-call-iptables = 1" \
                    "net.bridge.bridge-nf-call-ip6tables = 1" \
                    "net.ipv4.ip_forward = 1" \
    >/etc/sysctl.d/k3s.conf

    sysctl --system

    #### Install K3s ####
    log "Installing K3s..."
    INSTALL_K3S_EXEC="server \
        --node-name ${K3S_NODE_NAME} \
        --cluster-cidr ${K3S_CLUSTER_CIDR} \
        --service-cidr ${K3S_SERVICE_CIDR} \
        --disable ${K3S_DISABLE_COMPONENTS}"

    export INSTALL_K3S_EXEC
    [[ -n "$K3S_VERSION" ]] && export INSTALL_K3S_VERSION="$K3S_VERSION"

    curl -sfL https://get.k3s.io | sh -

    #### Install HELM ####
    log "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm -f get_helm.sh

    #### Post-install Configuration ####
    log "Waiting for K3s to become ready..."
    sleep 10

    #### Configure shell profile ####
    log "Configuring shell profile variables..."
    printf '%s\n'  "# K3S & Helm integration" \
                   "export KUBECONFIG=${K3S_KUBECONFIG_FILE}" \
    >${K3S_PROFILE_FILE}

    export KUBECONFIG=${K3S_PROFILE_FILE} # Ensure current shell picks it up if running interactively

    log "Setting up file permissions..."
    chmod 644 ${K3S_KUBECONFIG_FILE}
    chmod 644 ${K3S_PROFILE_FILE}

    log "Enabling kubectl autocompletion..."
    kubectl completion bash >/etc/bash_completion.d/kubectl

    #### Verification ####
    log "Verifying cluster status..."
    kubectl get nodes
    kubectl get pods -A

    log "K3s installation and basic configuration completed successfully."

    log "Validating Helm installation..."
    helm version

    log "Validating Kubernetes connectivity via Helm..."
    helm ls >/dev/null

    log "Helm successfully installed and integrated with k3s."
    log "KUBECONFIG is set system-wide via ${PROFILE_FILE}"

}


##############################
# Uninstall K3S & HELM Logic #
##############################

uninstall_k3s() {
  log "Starting K3s uninstall..."

  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    /usr/local/bin/k3s-uninstall.sh
  else
    log "K3s uninstall script not found. Skipping."
  fi

  log "Removing K3s directories..."
  rm -rf \
    /etc/rancher \
    /var/lib/rancher \
    /var/lib/kubelet \
    /var/log/containers \
    /var/log/pods \
    /etc/systemd/system/k3s.service \
    /etc/systemd/system/k3s-agent.service

  log "Reloading systemd..."
  systemctl daemon-reload

  log "Reverting sysctl configuration..."
  rm -f /etc/sysctl.d/k3s.conf
  sysctl --system

  log "Removing kernel module config..."
  rm -f /etc/modules-load.d/k3s.conf

  log "Re-enabling swap if previously disabled..."
  if [[ -f /etc/fstab.bak ]]; then
    mv /etc/fstab.bak /etc/fstab
    swapon -a || true
  fi

  log "Removing kubeconfig environment..."
  rm -f /etc/profile.d/k3s.sh

  #TODO: check if it's optionally indeed
  log "Optionally removing dependencies..."
  apt remove -y "${DEPENDENCIES[@]}" || true
  apt autoremove -y || true

  log "K3s uninstall and cleanup completed."

  # Remove Helm if installed via snap
  if snap list 2>/dev/null | grep -q "^helm "; then
      echo "Removing Helm (snap)..."
      snap remove helm
  fi

# Remove Helm if installed via apt
  if dpkg -l | grep -q "^ii.*helm "; then
      echo "Removing Helm (apt)..."
      apt-get remove -y helm
  fi

# Remove Helm binary if installed manually
  if command -v helm >/dev/null 2>&1; then
      HELM_PATH="$(command -v helm)"
      echo "Removing Helm binary at ${HELM_PATH}..."
      rm -f "${HELM_PATH}"
  fi

# Remove Helm configuration and cache
  log "Removing Helm configuration and cache..."
  rm -rf \
      ~/.config/helm \
      ~/.cache/helm \
      ~/.local/share/helm

  log "=== Helm fully removed ==="
}

#################################
# Stopping & Disable  - K3S     #
#################################

disable_k3s() {
  log "=== Stopping and disabling k3s (no removal) ==="

  # Stop and disable k3s services if present
  for svc in k3s k3s-agent; do
      if systemctl list-unit-files | grep -q "^${svc}.service"; then
          echo "Stopping ${svc}..."
          systemctl stop "${svc}" || true

          echo "Disabling ${svc}..."
          systemctl disable "${svc}" || true
      else
          echo "${svc}.service not found — skipping"
      fi
  done

  # Kill any remaining k3s processes (without deleting anything)
  log "Ensuring no k3s processes are running..."
  pkill -f k3s || true

  log "=== k3s stopped and disabled ==="
}

enable_k3s() {
  log "=== Enabling and starting k3s ==="

  # Enable and start k3s services if present
  for svc in k3s k3s-agent; do
      if systemctl list-unit-files | grep -q "^${svc}.service"; then
          log "Enabling ${svc}..."
          systemctl enable "${svc}"

          log "Starting ${svc}..."
          systemctl start "${svc}"
      else
          log "${svc}.service not found — skipping"
      fi
  done

  log "=== k3s enabled and started ==="
}

status_k3s() {
    echo "=============================="
    echo " k3s / Helm Exhaustive Status "
    echo "=============================="
    echo

    ########################
    # k3s service status
    ########################
    echo "k3s systemd services:"
    for svc in k3s k3s-agent; do
        if systemctl list-unit-files | grep -q "^${svc}.service"; then
            ACTIVE="$(systemctl is-active ${svc} 2>/dev/null || true)"
            ENABLED="$(systemctl is-enabled ${svc} 2>/dev/null || true)"

            echo "  - ${svc}.service"
            echo "      Active : ${ACTIVE}"
            echo "      Enabled: ${ENABLED}"
        else
            echo "  - ${svc}.service : NOT INSTALLED"
        fi
    done
    echo

    ########################
    # k3s processes
    ########################
    echo "k3s running processes:"
    if pgrep -fa k3s >/dev/null 2>&1; then
        pgrep -fa k3s
    else
        echo "  No k3s processes running"
    fi
    echo

    ########################
    # k3s API health (best-effort)
    ########################
    echo "k3s API server health:"
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "  kubectl reachable and cluster responding"
        else
            echo "  kubectl present but cluster NOT responding"
        fi
    else
        echo "  kubectl not found"
    fi
    echo

    ########################
    # k3s data presence (no deletion)
    ########################
    echo "k3s data directories:"
    for d in /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s; do
        if [ -d "$d" ]; then
            echo "  - $d : PRESENT"
        else
            echo "  - $d : absent"
        fi
    done
    echo

    ########################
    # Helm status
    ########################
    echo "Helm status:"

    if command -v helm >/dev/null 2>&1; then
        HELM_PATH="$(command -v helm)"
        echo "  Helm binary   : PRESENT"
        echo "  Path          : ${HELM_PATH}"

        if [ -f "${HELM_PATH}.disabled" ]; then
            echo "  State         : DISABLED (wrapper active)"
        else
            echo "  State         : ENABLED"
        fi

        echo "  Version       :"
        helm version --short 2>/dev/null || echo "    Unable to query version"
    else
        echo "  Helm binary   : NOT FOUND"
        for p in /usr/bin/helm /usr/local/bin/helm; do
            if [ -f "${p}.disabled" ]; then
                echo "  Disabled Helm : ${p}.disabled present"
            fi
        done
    fi
    echo

    ########################
    # Helm config presence
    ########################
    echo "Helm configuration:"
    for d in ~/.config/helm ~/.cache/helm ~/.local/share/helm; do
        if [ -d "$d" ]; then
            echo "  - $d : PRESENT"
        else
            echo "  - $d : absent"
        fi
    done
    echo

    ########################
    # Summary
    ########################
    echo "Summary:"
    for svc in k3s k3s-agent; do
        if systemctl list-unit-files | grep -q "^${svc}.service"; then
            ACTIVE="$(systemctl is-active ${svc} 2>/dev/null || true)"
            ENABLED="$(systemctl is-enabled ${svc} 2>/dev/null || true)"
            echo "  ${svc}: active=${ACTIVE}, enabled=${ENABLED}"
        fi
    done

    if command -v helm >/dev/null 2>&1; then
        if [ -f "$(command -v helm).disabled" ]; then
            echo "  Helm: disabled"
        else
            echo "  Helm: enabled"
        fi
    else
        echo "  Helm: not installed"
    fi

    echo
    echo "Status check complete."
}

############################
# Main                     #
############################

require_root
require_ubuntu

ACTION="${1:-status}"

case "$ACTION" in
  install)
    install_k3s
    ;;
  uninstall)
    uninstall_k3s
    ;;
  enable)
    enable_k3s
    ;;
  disable)
    disable_k3s
    ;;
  status)
    status_k3s
    ;;
  *)
    error "Usage: $0 {install|uninstall|enable|disable}"
    ;;
esac