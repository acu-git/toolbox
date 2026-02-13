#!/usr/bin/env bash
# ==============================================================================
# Description:   	Configure user aliases (my personal selection)
# Dependencies:     none
# Bash_version:	    GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
# Author email:     aurel_cuvin@yahoo.com
# ===============================================================================

# ================================================== #
# =====================  DOCKER  =================== #
# ================================================== #

# --------------------
# CORE DOCKER COMMANDS
# --------------------
alias d='docker'
alias di='docker images'
alias dins='docker inspect'

# -------------
# DOCKER STACK
# -------------
alias dst='docker stack'
alias dstl='docker stack list'
alias dsvc='docker service'
alias dsvcl='docker service list'

# ------------------------------
# STACK-LEVEL INSPECTION ALIASES
# ------------------------------

# Show Services in a Stack (Compact)
dstsvc() {
  docker stack services "$1" \
    --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Ports}}"
}

# Show Tasks in Stack (with Node + Status)
dsttasks() {
  docker stack ps "$1" \
    --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}"
}

# Show Only Failed Tasks in Stack
dstfail() {
  docker stack ps "$1" \
    --filter desired-state=shutdown \
    --format "table {{.Name}}\t{{.Node}}\t{{.Error}}"
}

# ----------------------------------
# Service-Level Deep Debug Functions
# ----------------------------------

# Full Service Deep Inspect (Readable)
dsvcdeep() {
  docker service inspect "$1" --pretty
}

# Check Service Resource Limits
dsvclimits() {
  docker service inspect "$1" \
    --format 'Limits: {{json .Spec.TaskTemplate.Resources.Limits}}
Reservations: {{json .Spec.TaskTemplate.Resources.Reservations}}'
}

# ------------------------------------
# Task → Container → Node Traceability
# ------------------------------------

# Map Service Tasks to Container IDs
dsvctocont() {
  docker service ps "$1" --no-trunc \
    --format '{{.Name}} {{.Node}} {{.ID}}'
}

# Find Running Container for a Service Task
dsvccid() {
  docker ps --filter label=com.docker.swarm.service.name="$1" \
    --format "table {{.Names}}\t{{.ID}}\t{{.Status}}\t{{.RunningFor}}"
}

# Exec Into First Running Replica of Service
dsvcexec() {
  cid=$(docker ps \
    --filter label=com.docker.swarm.service.name="$1" \
    -q | head -n1)
  docker exec -it "$cid" /bin/bash
}

# ---------------------------------
# Failure & Crash Loop Diagnostics
# ---------------------------------
# Stream Logs for All Replicas
dsvclogs() {
  docker service logs -f --tail=200 "$1"
}

# Show Recent Task Errors
dsvcerr() {
  docker service ps "$1" --no-trunc \
    --format '{{.Name}} {{.Error}}' | grep -v "Running"
}

# ----------------------------------------
# Networking Debugging (Overlay Networks)
# ----------------------------------------

# Show Networks for Stack
dstacknet() {
  docker network ls \
    --filter label=com.docker.stack.namespace="$1"
}

# Inspect Overlay Network (Readable)
dnetdeep() {
  docker network inspect "$1" | jq '.[0] | {Name,Driver,Scope,Peers,Containers}'
}

# Show Containers Attached to Network
dnetcont() {
  docker network inspect "$1" \
    --format '{{range $k,$v := .Containers}}{{$v.Name}} {{end}}'
}


# --------------------
# CONTAINER MANAGEMENT
# --------------------
# Get running containers
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

# Get all containers (including stoped containers)
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'


# -----------------------
# INSPECTION & DEBUGGING
# -----------------------
alias dlogs='docker logs -f --tail=200'

# -----------------------------------------------
# High-Signal Debug Bundle (One Command Overview)
# -----------------------------------------------

# This gives a fast operational summary of a stack:

dstdebug() {
  echo "=== SERVICES ==="
  docker stack services $1
  echo
  echo "=== TASKS ==="
  docker stack ps $1
  echo
  echo "=== NETWORKS ==="
  docker network ls --filter label=com.docker.stack.namespace=$1
}


# --------------------
# ADVANCED FUNCTIONS
# --------------------

# Remove all stopped containers
drmdead() {
    docker rm "$(docker ps -aq -f status=exited)"
}

# Bash into running container
dbash() { 
    docker exec -it "$(docker ps -aqf "name=$1")" bash
}

# Show all alias related docker
dalias() { 
    alias | grep 'docker' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/" | sed "s/['|\']//g" | sort
} 

# Show Container IP Address
dipaddr() {
    docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
}

# Clean Everything Safely (Interactive)
dclean() {
    echo "Pruning containers, networks, volumes, and images..."
    docker system prune -a --volumes
}

# Show Containers by Resource Usage (Sorted)
dmem() {
  docker stats --no-stream --format \
  "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Show Overlay Networks (Swarm)
doverlay() {
  docker network ls --filter driver=overlay
}



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
# ================  UBUNTU 22.04 LTS  ============== #
# ================================================== #

# ----------------------------------------------
# Package management
# ----------------------------------------------
# alias aptinst='sudo apt-get --yes --no-install-recommends install'
# alias aptrm='sudo apt-get remove --yes'
# alias aptup='sudo apt-get update && sudo apt-get upgrade --yes'
# alias aptclean='sudo apt autoremove -y && sudo apt clean'

# human readable df
alias ll='ls -halF'
alias df='df -h'


# ================================================== #
# ===   Save aliases to a file for persistence   === #
# ================================================== #
[[ -f ~/.bash_aliases ]] && mv ~/.bash_aliases ~/.old_bash_aliases
alias > ~/.bash_aliases
printf "Aliases defined and saved to ~/.bash_aliases\n"