#!/usr/bin/env bash

set -e

TIGERVNC_PACKAGES=(tigervnc-standalone-server tigervnc-common tigervnc-tools tigervnc-viewer tigervnc-xorg-extension)

echo "🖥️  TigerVNC manager (install / uninstall)"
echo "-----------------------------------------"

# Safety check
if [[ "$EUID" -eq 0 ]]; then
  echo "❌ Do not run this script as root."
  exit 1
fi

USER_NAME="$(whoami)"
HOME_DIR="$HOME"
VNC_DIR="$HOME_DIR/.vnc"
DISPLAY_NUM="1"

echo "👤 User: $USER_NAME"
echo

# ---- Mode selection ----
echo "Choose an action:"
echo "  1) Install & configure TigerVNC"
echo "  2) Completely uninstall TigerVNC and clean up"
read -rp "Select [1/2]: " MODE

if [[ "$MODE" == "2" ]]; then
  echo
  echo "⚠️  This will:"
  echo "  - Stop all running VNC servers for this user"
  echo "  - Remove TigerVNC packages"
  echo "  - Delete $VNC_DIR"
  echo
  read -rp "Are you sure you want to continue? [y/N]: " CONFIRM_UNINSTALL

  if [[ ! "$CONFIRM_UNINSTALL" =~ ^[Yy]$ ]]; then
    echo "❎ Uninstall cancelled."
    exit 0
  fi

  echo
  echo "🛑 Stopping running VNC servers..."
  vncserver -list 2>/dev/null | awk '/^:/{print $1}' | while read -r d; do
    vncserver -kill "$d" || true
  done

  echo "📦 Removing TigerVNC packages..."
  sudo apt remove --purge -y tigervnc-standalone-server tigervnc-common
  sudo apt autoremove -y

  if [[ -d "$VNC_DIR" ]]; then
    echo "🧹 Removing $VNC_DIR"
    rm -rf "$VNC_DIR"
  fi

  echo
  echo "✅ TigerVNC completely removed."
  exit 0
fi

# ---- Detect Desktop Environment ----
echo "🔍 Detecting desktop environment..."

DESKTOP_CMD=""

if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
  case "$XDG_CURRENT_DESKTOP" in
    *XFCE*|*Xfce*)
      DESKTOP_CMD="startxfce4 &"
      ;;
    *GNOME*)
      DESKTOP_CMD="gnome-session &"
      ;;
    *KDE*)
      DESKTOP_CMD="startplasma-x11 &"
      ;;
    *MATE*)
      DESKTOP_CMD="mate-session &"
      ;;
    *LXDE*)
      DESKTOP_CMD="startlxde &"
      ;;
    *LXQt*)
      DESKTOP_CMD="startlxqt &"
      ;;
  esac
fi

# Fallback detection
if [[ -z "$DESKTOP_CMD" ]]; then
  if command -v startxfce4 >/dev/null; then
    DESKTOP_CMD="startxfce4 &"
  elif command -v gnome-session >/dev/null; then
    DESKTOP_CMD="gnome-session &"
  elif command -v startplasma-x11 >/dev/null; then
    DESKTOP_CMD="startplasma-x11 &"
  elif command -v mate-session >/dev/null; then
    DESKTOP_CMD="mate-session &"
  fi
fi

if [[ -z "$DESKTOP_CMD" ]]; then
  echo "❌ No graphical desktop environment detected."
  echo "Install a GUI first, then re-run this script."
  exit 1
fi

echo "✅ Detected desktop command: $DESKTOP_CMD"
echo

# ---- Confirm install ----
read -rp "📦 Install TigerVNC now? [y/N]: " CONFIRM_INSTALL

if [[ ! "$CONFIRM_INSTALL" =~ ^[Yy]$ ]]; then
  echo "❎ Installation cancelled."
  exit 0
fi

# ---- Update system ----
read -rp "🔄 Update package list? [Y/n]: " UPDATE_CHOICE
UPDATE_CHOICE=${UPDATE_CHOICE:-Y}

if [[ "$UPDATE_CHOICE" =~ ^[Yy]$ ]]; then
  sudo apt update
fi

# ---- Install TigerVNC ----
echo
echo "📦 Installing TigerVNC..."
sudo apt install -y tigervnc-standalone-server tigervnc-common

# ---- Configure VNC ----
mkdir -p "$VNC_DIR"
chmod 700 "$VNC_DIR"

echo
echo "🔐 Set your VNC password"
vncpasswd

echo
echo "🛠️  Writing VNC startup file..."

cat > "$VNC_DIR/xstartup" <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec $DESKTOP_CMD
EOF

chmod +x "$VNC_DIR/xstartup"

# Stop existing server if running
if vncserver -list 2>/dev/null | grep -q ":$DISPLAY_NUM"; then
  echo "🛑 Stopping existing VNC server on :$DISPLAY_NUM"
  vncserver -kill ":$DISPLAY_NUM"
fi

# Start VNC
echo
echo "🚀 Starting TigerVNC server on display :$DISPLAY_NUM"
vncserver ":$DISPLAY_NUM" -localhost no

IP_ADDR=$(hostname -I | awk '{print $1}')

echo
echo "✅ TigerVNC is ready!"
echo
echo "📌 Connection info:"
echo "   Address: $IP_ADDR:$((5900 + DISPLAY_NUM))"
echo "   Display: :$DISPLAY_NUM"
echo
echo "🧯 Stop server:"
echo "   vncserver -kill :$DISPLAY_NUM"
echo
echo "🔁 Restart server:"
echo "   vncserver :$DISPLAY_NUM"
