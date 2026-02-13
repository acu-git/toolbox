#!/usr/bin/env bash
# Ubuntu 24.04 GUI / Desktop Environment Overview
# Read-only diagnostic

set -euo pipefail
SEP="============================================================"

echo "$SEP"
echo "SYSTEM & DISPLAY STACK"
echo "$SEP"
lsb_release -d 2>/dev/null || true
echo "Kernel: $(uname -r)"

echo
echo "$SEP"
echo "DISPLAY MANAGER (LOGIN SCREEN)"
echo "$SEP"

if systemctl is-active --quiet display-manager; then
    echo "display-manager service: ACTIVE"
    systemctl status display-manager --no-pager | grep -E 'Loaded:|Active:|Main PID:'
else
    echo "display-manager service: NOT active"
fi

echo
echo "Configured default display manager:"
if [[ -f /etc/X11/default-display-manager ]]; then
    cat /etc/X11/default-display-manager
else
    echo "Not set"
fi

echo
echo "Installed display managers:"
dpkg -l | grep -E 'gdm3|sddm|lightdm|xdm' || echo "None detected"

echo
echo "$SEP"
echo "DESKTOP ENVIRONMENTS (INSTALLED)"
echo "$SEP"

dpkg -l | grep -E \
    'ubuntu-desktop|gnome-shell|plasma-desktop|kde-standard|xfce4|lxqt|mate-desktop' \
    || echo "No common desktop environments detected"

echo
echo "$SEP"
echo "AVAILABLE LOGIN SESSIONS"
echo "$SEP"
ls /usr/share/xsessions 2>/dev/null || echo "No X11 sessions found"
echo
ls /usr/share/wayland-sessions 2>/dev/null || echo "No Wayland sessions found"

echo
echo "$SEP"
echo "CURRENT USER GUI SESSION"
echo "$SEP"

if [[ -n "${XDG_SESSION_ID:-}" ]]; then
    loginctl show-session "$XDG_SESSION_ID" \
        -p Type -p Class -p Name -p Display -p Remote -p State
else
    echo "No active GUI session detected for current shell"
fi

echo
echo "Session environment variables:"
env | grep -E 'XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP|DESKTOP_SESSION|WAYLAND_DISPLAY|DISPLAY' || true

echo
echo "$SEP"
echo "WAYLAND vs X11"
echo "$SEP"
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    echo "Active session: WAYLAND"
elif [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    echo "Active session: X11"
else
    echo "Session type: UNKNOWN or non-GUI"
fi

echo
echo "$SEP"
echo "GRAPHICS STACK"
echo "$SEP"

command -v glxinfo >/dev/null 2>&1 \
    && glxinfo -B 2>/dev/null | grep -E 'OpenGL vendor|OpenGL renderer|OpenGL version' \
    || echo "glxinfo not installed"

echo
echo "Xorg version:"
command -v Xorg >/dev/null 2>&1 && Xorg -version | head -n 1 || echo "Xorg not installed"

echo
echo "$SEP"
echo "REMOTE GUI SERVICES"
echo "$SEP"

for svc in xrdp vncserver gnome-remote-desktop; do
    if systemctl list-unit-files | grep -q "^${svc}\.service"; then
        systemctl is-active --quiet "$svc" \
            && echo "$svc: ACTIVE" \
            || echo "$svc: INSTALLED but NOT active"
    fi
done

echo
echo "$SEP"
echo "SUMMARY"
echo "$SEP"
echo "✔ Display manager, desktop environments, session type, graphics stack"
echo "✔ Wayland/X11 and local vs remote GUI visibility"
echo "✔ Safe to run on servers and desktops"


echo
echo "$SEP"
echo "BOOT MILESTONE / BOOT TARGET CONFIGURATION"
echo "$SEP"

# Default boot target
echo "Default boot target:"
systemctl get-default

echo
echo "Currently active targets:"
systemctl list-units --type=target --state=active

echo
echo "$SEP"
echo "GRAPHICAL BOOT TARGET DETAILS"
echo "$SEP"

if systemctl is-enabled graphical.target >/dev/null 2>&1; then
    echo "graphical.target: ENABLED"
else
    echo "graphical.target: DISABLED"
fi

if systemctl is-enabled multi-user.target >/dev/null 2>&1; then
    echo "multi-user.target: ENABLED"
else
    echo "multi-user.target: DISABLED"
fi

echo
echo "graphical.target dependencies:"
systemctl list-dependencies graphical.target | grep -E 'display-manager|gdm|sddm|lightdm' || \
    echo "No display manager dependency detected"

echo
echo "$SEP"
echo "DISPLAY MANAGER BOOT INTEGRATION"
echo "$SEP"

if systemctl is-enabled display-manager >/dev/null 2>&1; then
    echo "display-manager service: ENABLED at boot"
else
    echo "display-manager service: NOT enabled at boot"
fi

echo
echo "$SEP"
echo "KERNEL BOOT PARAMETERS (GRAPHICS-RELATED)"
echo "$SEP"

if [[ -r /proc/cmdline ]]; then
    cat /proc/cmdline | tr ' ' '\n' | grep -E \
        'quiet|splash|nomodeset|nvidia|i915|amdgpu|radeon|wayland' || \
        echo "No graphics-related kernel parameters found"
else
    echo "Unable to read /proc/cmdline"
fi

echo
echo "$SEP"
echo "BOOT COMPLETION SIGNALS"
echo "$SEP"

echo "Time to reach graphical target (last boot):"
systemd-analyze blame | grep -E 'display-manager|gdm|graphical.target' || echo "No data available"

echo
echo "Boot milestone timestamps:"
systemd-analyze | grep -E 'kernel|userspace|graphical'
