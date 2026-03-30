#!/usr/bin/env bash
# ==============================================================================
# Description:   	Configure user aliases (my personal selection)
# Dependencies:     none
# Bash_version:	    GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
# Author email:     aurel_cuvin@yahoo.com
# ===============================================================================

# ================================================== #
# ====================  ALIASES  =================== #
# ================================================== #

# --------------------
# DOCKER COMMANDS
# --------------------
alias d='docker'

alias dst='docker stack'
alias dstl='docker stack list'
alias dsvc='docker service'
alias dsvcl='docker service list'

alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'  # Get running containers
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'  # Get all containers (including stoped containers)

alias dlogs='docker logs -f --tail=200'
alias dlogst='docker logs --tail 100 -f'

# Show container resource usage in a clean format
alias dstat='docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"'
# Live monitoring of container stats
alias dstatwatch='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
# Get the IP address of a container


# ================================================== #
# ===================  KUBERNETES  ================= #
# ================================================== #

# # kubectl get basic
# alias k='kubectl'
# alias kg='kubectl get'
# alias kd='kubectl describe'

# # kubectl get resources types
# alias kall='kubectl get all'
# alias knode='kubectl get nodes'
# alias kns='kubectl get namespaces'
# alias kpod='kubectl get pods'
# alias ksvc='kubectl get services'
# alias kdeploy='kubectl get deployments'

# # kubectl exec
# alias kex='kubectl exec'
# alias kexi='kubectl exec -it'

# # kubectl logs
# alias klog='kubectl logs'
# alias klogf='kubectl logs -f'

# # kubectl delete
# alias kdel='kubectl delete'
# alias kdelf='kubectl delete -f'

# ================================================== #
# ================  UBUNTU 24.04 LTS  ============== #
# ================================================== #

# ----------------------------------------------
# Package management
# ----------------------------------------------
alias aptinst='sudo apt-get --yes --no-install-recommends install'
alias aptrm='sudo apt-get remove --yes'
alias aptupg='sudo apt-get update && sudo apt-get upgrade --yes'
alias aptclean='sudo apt autoremove -y && sudo apt clean'


# ================================================== #
# ===   Save aliases to a file for persistence   === #
# ================================================== #
[[ -f ~/.bash_aliases ]] && mv ~/.bash_aliases ~/.old_bash_aliases
alias > ~/.bash_aliases
printf "Aliases defined and saved to ~/.bash_aliases\n"


# 3. Append the sourcing logic to .bashrc (with a safety check)
if [ -f ./.functions ]; then
  cp ./.functions ~/.functions
  cat << 'EOF' >> ~/.bashrc

if [ -f ~/.functions ]; then
    . ~/.functions
fi
EOF
fi