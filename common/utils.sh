#!/usr/bin/env bash
#
# common-logging.sh - Reusable logging library with header support
# Version: 2.0.0
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/common-logging.sh"
# Designed to be safely sourced by other libraries

# ============================================
# INITIALIZATION GUARD
# ============================================
# Prevent multiple initializations
if [[ -n "${__COMMON_LOGGING_LOADED:-}" ]]; then
    # Already loaded, just return
    return 0
fi

# ============================================
# LIBRARY METADATA
# ============================================
readonly __COMMON_LOGGING_LOADED=true
readonly __COMMON_LOGGING_NAME="common-logging"
readonly __COMMON_LOGGING_VERSION="2.0.0"

# ============================================
# CONFIGURATION DEFAULTS
# ============================================
# All configs can be overridden before sourcing
: "${LOG_DEBUG_MODE:=false}"                            # Enable debug messages
: "${LOG_FILE_LOGGING:=false}"                          # Enable file logging
: "${LOG_TIMESTAMP_FORMAT:='+"%Y-%m-%d %H:%M:%S"'}"     # date format
: "${LOG_FILE_PATH:="./script.log"}"                    # Default log file path
: "${LOG_COLOR_MODE:=auto}"                             # auto, always, never
: "${LOG_AUTO_INIT:=true}"                              # Auto-initialize on load

# ============================================
# TERMINAL COLOR DETECTION
# ============================================
__log::_detect_colors() {
    case "${LOG_COLOR_MODE}" in
        always)
            __LOG_USE_COLORS=true
            ;;
        never)
            __LOG_USE_COLORS=false
            ;;
        auto|*)
            # Check if stdout is a terminal
            if [[ -t 1 ]]; then
                __LOG_USE_COLORS=true
            else
                __LOG_USE_COLORS=false
            fi
            ;;
    esac
}

# ============================================
# COLOR SETUP (conditional)
# ============================================
if __log::_detect_colors && [[ "${__LOG_USE_COLORS}" == true ]]; then
    # Use tput for portability if available
    if command -v tput >/dev/null 2>&1; then
        readonly LOG_COLOR_RED=$(tput setaf 1)
        readonly LOG_COLOR_GREEN=$(tput setaf 2)
        readonly LOG_COLOR_YELLOW=$(tput setaf 3)
        readonly LOG_COLOR_BLUE=$(tput setaf 4)
        readonly LOG_COLOR_MAGENTA=$(tput setaf 5)
        readonly LOG_COLOR_CYAN=$(tput setaf 6)
        readonly LOG_COLOR_BOLD=$(tput bold)
        readonly LOG_COLOR_RESET=$(tput sgr0)
    else
        # Fallback to ANSI codes
        readonly LOG_COLOR_RED='\033[0;31m'
        readonly LOG_COLOR_GREEN='\033[0;32m'
        readonly LOG_COLOR_YELLOW='\033[0;33m'
        readonly LOG_COLOR_BLUE='\033[0;34m'
        readonly LOG_COLOR_MAGENTA='\033[0;35m'
        readonly LOG_COLOR_CYAN='\033[0;36m'
        readonly LOG_COLOR_BOLD='\033[1m'
        readonly LOG_COLOR_RESET='\033[0m'
    fi
else
    # No colors
    readonly LOG_COLOR_RED=''
    readonly LOG_COLOR_GREEN=''
    readonly LOG_COLOR_YELLOW=''
    readonly LOG_COLOR_BLUE=''
    readonly LOG_COLOR_MAGENTA=''
    readonly LOG_COLOR_CYAN=''
    readonly LOG_COLOR_BOLD=''
    readonly LOG_COLOR_RESET=''
fi

# ============================================
# PRIVATE HELPER FUNCTIONS
# ============================================

# Creates a string by repeating a char N times
# @param $1: Number of repetitions (default: 80)
# @param $2: Character to repeat (default: '=')
__log::_char_repeat() {
    local length="${1:-80}"
    local char="${2:-=}"
    printf "%${length}s" | tr ' ' "${char}"
}

# Get formatted timestamp
__log::_get_timestamp() {
    date "${LOG_TIMESTAMP_FORMAT}"
}

# Write to log file if enabled
__log::_write_to_file() {
    local message="$1"
    
    if [[ "${LOG_FILE_LOGGING}" == true ]] && [[ -n "${LOG_FILE_PATH}" ]]; then
        # Ensure directory exists
        local log_dir
        log_dir=$(dirname "${LOG_FILE_PATH}")
        mkdir -p "${log_dir}" 2>/dev/null || true
        
        # Write to file
        printf "%s\n" "${message}" >> "${LOG_FILE_PATH}"
    fi
}

# Write to both stdout and file if needed
__log::_output() {
    local message="$1"
    local to_stderr="${2:-false}"
    
    if [[ "${to_stderr}" == true ]]; then
        printf "%s\n" "${message}" >&2
    else
        printf "%s\n" "${message}"
    fi
    
    __log::_write_to_file "${message}"
}

# ============================================
# HEADER FUNCTIONS (Private)
# ============================================

__log::_h1_header() {
    local title="$1"
    local -i title_length="${#title}"
    local -i width=54
    
    if [[ ${title_length} -ge $((width-8)) ]]; then
        width=$((title_length+8))
    fi
    
    local dashes
    dashes=$(__log::_char_repeat "$width" '=')
    local now_iso
    now_iso=$(date -u +"%Y-%m-%dT%H:%M:%3NZ")
    local ux_timestamp
    ux_timestamp=$(date +"%s")
    
    printf "%b\n" \
        "${LOG_COLOR_CYAN}${dashes}${LOG_COLOR_RESET}" \
        "${LOG_COLOR_CYAN}${LOG_COLOR_BOLD}=== ${title} ===${LOG_COLOR_RESET}" \
        "${LOG_COLOR_CYAN}=== Started on: ${now_iso} (${ux_timestamp}) ===${LOG_COLOR_RESET}" \
        "${LOG_COLOR_CYAN}${dashes}${LOG_COLOR_RESET}"
}

__log::_h2_header() {
    local title="$1"
    local -i title_length="${#title}"
    local -i width=54
    
    if [[ ${title_length} -ge $((width-8)) ]]; then
        width=$((title_length+8))
    fi
    
    local dashes
    dashes=$(__log::_char_repeat "$width" '-')
    
    printf "%b\n" \
        "${LOG_COLOR_BLUE}${dashes}${LOG_COLOR_RESET}" \
        "${LOG_COLOR_BLUE}${LOG_COLOR_BOLD}=== ${title} ===${LOG_COLOR_RESET}" \
        "${LOG_COLOR_BLUE}${dashes}${LOG_COLOR_RESET}"
}

# ============================================
# PUBLIC LOGGING API
# ============================================

# H1 Header
log::h1() {
    local title="${1:-}"
    local output
    output=$(__log::_h1_header "${title}")
    __log::_output "${output}"
}

# H2 Header
log::h2() {
    local title="${1:-}"
    local output
    output=$(__log::_h2_header "${title}")
    __log::_output "${output}"
}

# Info level
log::info() {
    local message="$1"
    local timestamp
    timestamp=$(__log::_get_timestamp)
    local formatted="${timestamp} [INFO] ${message}"
    __log::_output "${formatted}"
}

# Success level
log::success() {
    local message="$1"
    local timestamp
    timestamp=$(__log::_get_timestamp)
    local formatted="${timestamp} ${LOG_COLOR_GREEN}[OK]${LOG_COLOR_RESET} ${message}"
    __log::_output "${formatted}"
}

# Warning level
log::warn() {
    local message="$1"
    local timestamp
    timestamp=$(__log::_get_timestamp)
    local formatted="${timestamp} ${LOG_COLOR_YELLOW}[WARN]${LOG_COLOR_RESET} ${message}"
    __log::_output "${formatted}"
}

# Error level
log::error() {
    local message="$1"
    local timestamp
    timestamp=$(__log::_get_timestamp)
    local formatted="${timestamp} ${LOG_COLOR_RED}[ERROR]${LOG_COLOR_RESET} ${message}"
    __log::_output "${formatted}" true  # Send to stderr
}

# Debug level (only if debug mode is enabled)
log::debug() {
    local message="$1"
    
    if [[ "${LOG_DEBUG_MODE}" == true ]]; then
        local timestamp
        timestamp=$(__log::_get_timestamp)
        local formatted="${timestamp} ${LOG_COLOR_MAGENTA}[DEBUG]${LOG_COLOR_RESET} ${message}"
        __log::_output "${formatted}"
    fi
}

# ============================================
# CONFIGURATION MANAGEMENT
# ============================================

# Initialize logging system
log::init() {
    if [[ -n "${__LOG_INITIALIZED:-}" ]]; then
        log::debug "Logging already initialized"
        return 0
    fi
    
    # Validate configurations
    if [[ "${LOG_FILE_LOGGING}" == true ]] && [[ -z "${LOG_FILE_PATH}" ]]; then
        echo "Warning: File logging enabled but LOG_FILE_PATH not set" >&2
        LOG_FILE_LOGGING=false
    fi
    
    # Create log file directory if needed
    if [[ "${LOG_FILE_LOGGING}" == true ]] && [[ -n "${LOG_FILE_PATH}" ]]; then
        local log_dir
        log_dir=$(dirname "${LOG_FILE_PATH}")
        if ! mkdir -p "${log_dir}" 2>/dev/null; then
            echo "Warning: Cannot create log directory: ${log_dir}" >&2
            LOG_FILE_LOGGING=false
        fi
    fi
    
    readonly __LOG_INITIALIZED=true
    log::debug "Logging initialized (debug=${LOG_DEBUG_MODE}, file=${LOG_FILE_LOGGING})"
}

# Update configuration at runtime
log::set_debug() {
    local value="${1:-true}"
    case "${value}" in
        true|1|on|yes) LOG_DEBUG_MODE=true ;;
        false|0|off|no) LOG_DEBUG_MODE=false ;;
        *) log::error "Invalid debug value: ${value}" ; return 1 ;;
    esac
    log::debug "Debug mode set to: ${LOG_DEBUG_MODE}"
}

log::set_file_logging() {
    local value="${1:-true}"
    local path="${2:-}"
    
    case "${value}" in
        true|1|on|yes) LOG_FILE_LOGGING=true ;;
        false|0|off|no) LOG_FILE_LOGGING=false ;;
        *) log::error "Invalid file logging value: ${value}" ; return 1 ;;
    esac
    
    if [[ -n "${path}" ]]; then
        LOG_FILE_PATH="${path}"
    fi
    
    log::debug "File logging set to: ${LOG_FILE_LOGGING}"
    if [[ "${LOG_FILE_LOGGING}" == true ]]; then
        log::debug "Log file: ${LOG_FILE_PATH}"
    fi
}

# Get current configuration
log::get_config() {
    cat <<EOF
DEBUG_MODE=${LOG_DEBUG_MODE}
FILE_LOGGING=${LOG_FILE_LOGGING}
LOG_FILE=${LOG_FILE_PATH}
TIMESTAMP_FORMAT=${LOG_TIMESTAMP_FORMAT}
COLOR_MODE=${LOG_COLOR_MODE}
EOF
}

# ============================================
# UTILITY FUNCTIONS
# ============================================

# Log a section with timing
log::timed_section() {
    local title="$1"
    shift
    
    log::h1 "${title}"
    local start_time
    start_time=$(date +%s)
    
    # Execute the command
    "$@"
    local exit_code=$?
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log::success "'${title}' completed in ${duration} seconds"
    else
        log::error "'${title}' failed after ${duration} seconds (exit code: ${exit_code})"
    fi
    
    return $exit_code
}

# Log with variable inspection
log::inspect() {
    local message="$1"
    shift
    
    log::info "${message}"
    for var in "$@"; do
        if [[ -v "${var}" ]]; then
            log::debug "  ${var}=${!var}"
        else
            log::debug "  ${var}=<unset>"
        fi
    done
}

# ============================================
# INITIALIZATION
# ============================================

# Auto-initialize if enabled
if [[ "${LOG_AUTO_INIT}" == true ]]; then
    log::init
fi

# Export public functions for use in subshells
declare -fx log::h1 log::h2 log::info log::success log::warn log::error log::debug
declare -fx log::init log::set_debug log::set_file_logging log::get_config
declare -fx log::timed_section log::inspect

# ============================================
# COMPATIBILITY SHIMS (optional)
# ============================================
# If you want to maintain backward compatibility with old function names
# Uncomment these if needed:
#
# log_h1() { log::h1 "$@"; }
# log_h2() { log::h2 "$@"; }
# log_info() { log::info "$@"; }
# log_success() { log::success "$@"; }
# log_warn() { log::warn "$@"; }
# log_error() { log::error "$@"; }
# log_debug() { log::debug "$@"; }

# ============================================
# LOAD COMPLETION
# ============================================
log::debug "Common logging library v${__COMMON_LOGGING_VERSION} loaded"