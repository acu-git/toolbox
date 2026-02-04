#!/usr/bin/env bash
# common-logging.sh - Reusable logging library
# Designed to be safely sourced by other libraries/scripts

# Enable strict mode for better error handling
set -o errexit   # Exit on error
set -o nounset   # Exit on unset variable
set -o pipefail  # Capture pipe failures

# --------------------------------------------------
# Guard against multiple sourcing
# --------------------------------------------------
if [[ -n "${_COMMON_LOGGING_SOURCED:-}" ]]; then
    return 0
fi
readonly _COMMON_LOGGING_SOURCED=1

###################
####  GLOBALS  ####
###################

# Allow callers to override before sourcing
: "${TIMESTAMP_FORMAT:=+%Y-%m-%d\ %H:%M:%S}"
: "${DEBUG_MODE:=False}"
: "${FILE_LOGGING:=False}"
: "${LOG_FILE:=./${TIMESTAMP_FORMAT}_script.log}"

# -----------------------
# Set terminal colormaps
# -----------------------
RED=$(tput setaf 1)     #RED="\033[0;31m"
GREEN=$(tput setaf 2)   #GREEN="\033[0;32m"
YELLOW=$(tput setaf 3)  #YELLOW="\033[0;33m"
BLUE=$(tput setaf 4)    #BLUE="\033[0;34m"
MAGENTA=$(tput setaf 5) #MAGENTA="\033[0;35m"
CYAN=$(tput setaf 6)    #CYAN="\033[0;36m"
# WHITE=$(tput setaf 7)   #WHITE="\033[0;37m"

BOLD=$(tput bold)       # BOLD='\033[1m'
NB="\033[22m"           # Reset bold
NC=$(tput sgr0)   # RESET="\e[0m"
# ULINE=$(tput smul)      # ULINE='\033[4m'


# ############################
# ###  AUXILIAR FUNCTIONS  ###
# ############################

# -------------------------------------------------------
# Creates a string by repeating a char N times
# @arg1 - nr. of repetitions; @arg2 - char to be repeated
# -------------------------------------------------------
function charRepeat(){
	local length=${1:-80}
	local str="${2:-=}"
    printf "%${length}s" | tr ' ' "${str}"
}

# ---------------------------
# H1 Header printer
# @arg1 - Header Title string
# ---------------------------
function printh1() {
    declare -i arg_size=$((${#1}))
    declare -i n=54
    if [[ $arg_size -ge $((n-8)) ]]; then
        n=$((arg_size+8))
    fi
        dashes=$(charRepeat "$n" '=')
        #printf "%(%m-%d-%Y %H:%M:%S)T" $(date +%s)\n
		nowISO=$(date -u +"%Y-%m-%dT%H:%M:%3NZ")
        uxtimestamp=$(date +"%s")
        printf "${CYAN}%b\n${NC}" \
            "${dashes}" \
            "${BOLD}=== $1 ===${NB}" \
            "=== Started on: $nowISO ($uxtimestamp) ===" \
            "${dashes}"
}

# ---------------------------
# H2 Header printer
# @arg1 - Header Title string
# ---------------------------
function printh2() {
    declare -i arg_size=$((${#1}))
    declare -i n=54
    if [[ $arg_size -ge $((n-8)) ]]; then
        n=$((arg_size+8))
    fi
        dashes=$(charRepeat $n '-')
		printf "$BLUE%b\n$NC" \
            "$dashes" \
            "$BOLD=== $1 ===$NB" \
            "$dashes"
}

log::_emit() {
    local output

    output="$("$@")"

    if [[ "${FILE_LOGGING}" == "true" ]]; then
        printf '%s\n' "$output" | tee -a "${LOG_FILE}"
    else
        printf '%s\n' "$output"
    fi
}

# ################################
# ###  LOGGING MAIN FUNCTIONS  ###
# ################################

function log_h1() { log::_emit printh1 "${1}"
}

function log_h2() { log::_emit printh2 "${1}"
}

function log_info() {
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    log::_emit printf "%s %s\n" "${timestamp} [INFO]" "$1"
}

function log_success() {
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    log::_emit printf "%s %s\n" "${timestamp} ${GREEN}[OK]${NC}" "$1"
}

function log_warn() {
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    log::_emit printf "%s %s\n" "${timestamp} ${YELLOW}[WARN]${NC}" "$1"
}

function log_error() {
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    log::_emit printf "%s %s\n" "${timestamp} ${RED}[ERROR]${NC}" "$1"
}

function log_debug() {
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    if [ "${DEBUG_MODE}" = True ] ; then
        log::_emit printf "%s %s\n" "${timestamp} ${MAGENTA}[DEBUG]${NC}" "$1"
    fi
}



################
####  TEST  ####
################

# # TEST-01 Printing headers styles
# if [[ $1 == "test" || $1 == "test01" ]]; then
# # set -x
#     printf "H1 style sample short:\n"
#     printh1 "Header 1 Style Sample"
#     printf "H1 style sample long:\n"
#     printh1 "Header 1 Style Sample much longer message provided by default"
#     printf "H2 style sample long:\n"
#     printh2 "Header 1 Style Sample much longer message provided by default"
# fi

# # TEST-02 Printing log messages
# if [[ $1 == "test" || $1 == "test02" ]]; then
# # set -x
#     log_info "Salut bibi"
#     log_success "Operation completed successfully"
#     log_warn "This is a warning message"
#     log_error "This is an error message"
#     DEBUG_MODE=True
#     log_debug "This is a debug message"
#     DEBUG_MODE=False
# fi