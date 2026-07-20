#!/usr/bin/env bash

# ==============================================================================
# Bodhi Linux Software Update Notifier - Uninstallation Script
# ==============================================================================

# Define installation paths
INSTALL_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/bodhi-update-notifier"
AUTOSTART_DIR="$HOME/.config/autostart"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
APP_MENU_DIR="$HOME/.local/share/applications"

echo "=== Uninstalling Bodhi Update Notifier ==="

# 1. Stop and disable systemd service
if systemctl --user is-active bodhi-update-notifier.service &>/dev/null; then
    echo "-> Stopping systemd user service..."
    systemctl --user stop bodhi-update-notifier.service || true
fi

if systemctl --user is-enabled bodhi-update-notifier.service &>/dev/null; then
    echo "-> Disabling systemd user service..."
    systemctl --user disable bodhi-update-notifier.service || true
fi

# 2. Remove files
echo "-> Removing installed configurations and binaries..."
rm -f "$SYSTEMD_USER_DIR/bodhi-update-notifier.service"
rm -f "$AUTOSTART_DIR/bodhi-update-notifier.desktop"
rm -f "$APP_MENU_DIR/bodhi-update-notifier.desktop"
rm -f "$INSTALL_DIR/bodhi-update-notifier.sh"
rm -f "$INSTALL_DIR/bodhi-update-settings.py"
rm -f "$INSTALL_DIR/bodhi-update-tray.py"
rm -f "/tmp/bodhi-update-notifier-*.lock"

# 3. Reload systemd daemon
echo "-> Reloading systemd user configuration..."
systemctl --user daemon-reload

# 4. Ask user if they want to clean up logs/logo directory
read -p "Would you like to delete the logs and application data under $SHARE_DIR? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "-> Cleaning up logs and data..."
    rm -rf "$SHARE_DIR"
    rm -rf "$HOME/.config/bodhi-update-notifier"
fi

echo ""
echo "=================================================="
echo "✔ Uninstallation completed successfully!"
echo "=================================================="
