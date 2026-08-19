#!/usr/bin/env bash

# ==============================================================================
# Bodhi Linux Software Update Notifier - Installation Script
# ==============================================================================

set -e

# Define installation paths
INSTALL_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/bodhi-update-notifier"
AUTOSTART_DIR="$HOME/.config/autostart"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
APP_MENU_DIR="$HOME/.local/share/applications"

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Bodhi Update Notifier ==="

# 1. Create target directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$SHARE_DIR"
mkdir -p "$AUTOSTART_DIR"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$APP_MENU_DIR"

# 2. Copy the main script, settings app, and system tray applet
echo "-> Copying update notifier script..."
cp "$SCRIPT_DIR/bodhi-update-notifier.sh" "$INSTALL_DIR/bodhi-update-notifier.sh"
chmod +x "$INSTALL_DIR/bodhi-update-notifier.sh"

echo "-> Copying settings dashboard..."
cp "$SCRIPT_DIR/bodhi-update-settings.py" "$INSTALL_DIR/bodhi-update-settings.py"
chmod +x "$INSTALL_DIR/bodhi-update-settings.py"

echo "-> Copying notification popup..."
cp "$SCRIPT_DIR/bodhi-update-popup.py" "$INSTALL_DIR/bodhi-update-popup.py"
chmod +x "$INSTALL_DIR/bodhi-update-popup.py"

echo "-> Copying system tray applet..."
cp "$SCRIPT_DIR/bodhi-update-tray.py" "$INSTALL_DIR/bodhi-update-tray.py"
chmod +x "$INSTALL_DIR/bodhi-update-tray.py"

# 3. Copy resources (logo)
if [ -f "$SCRIPT_DIR/bodhi_update_logo.jpg" ]; then
    echo "-> Copying application logo..."
    cp "$SCRIPT_DIR/bodhi_update_logo.jpg" "$SHARE_DIR/bodhi_update_logo.jpg"
fi

# 4. Generate and copy the systemd user service dynamically
echo "-> Generating systemd user service..."
cat <<EOF > "$SYSTEMD_USER_DIR/bodhi-update-notifier.service"
[Unit]
Description=Bodhi Linux Software Update Notifier
After=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/bodhi-update-notifier.sh
Restart=on-failure
RestartSec=10
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF

# 5. Generate and copy the desktop autostart entry dynamically
echo "-> Generating desktop autostart entry..."
cat <<EOF > "$AUTOSTART_DIR/bodhi-update-notifier.desktop"
[Desktop Entry]
Type=Application
Name=Bodhi Update Notifier
Comment=Lightweight background update check & GUI notifier
Exec=$INSTALL_DIR/bodhi-update-notifier.sh
Icon=software-update-available
Terminal=false
Categories=System;Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
chmod +x "$AUTOSTART_DIR/bodhi-update-notifier.desktop"

# 5b. Generate and copy the applications menu shortcut dynamically
echo "-> Generating applications menu shortcut..."
cat <<EOF > "$APP_MENU_DIR/bodhi-update-notifier.desktop"
[Desktop Entry]
Type=Application
Name=Bodhi Update Notifier
Comment=Check and install Bodhi software updates
Exec=$INSTALL_DIR/bodhi-update-notifier.sh --show-details
Icon=software-update-available
Terminal=false
Categories=System;PackageManager;Utility;
StartupNotify=true
EOF
chmod +x "$APP_MENU_DIR/bodhi-update-notifier.desktop"

# 6. Enable and start the systemd user service
echo "-> Enabling and starting systemd user service..."
systemctl --user daemon-reload
systemctl --user enable bodhi-update-notifier.service
systemctl --user start bodhi-update-notifier.service

echo ""
echo "=================================================="
echo "✔ Installation completed successfully!"
echo "The update notifier is now running in the background."
echo "It will automatically start whenever you log in."
echo "Log file: $SHARE_DIR/notifier.log"
echo "=================================================="
