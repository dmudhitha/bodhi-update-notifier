#!/usr/bin/env bash
# ==============================================================================
# Bodhi Linux Software Update Notifier - Debian Package Builder
# ==============================================================================

set -e

# Set package variables
PKG_NAME="bodhi-update-notifier"
VERSION="1.0"
RELEASE="1"
ARCH="all"
BASE_DIR="/home/mudhitha/System/bodhi-update-notifier"
BUILD_DIR="$BASE_DIR/build-deb/${PKG_NAME}_${VERSION}-${RELEASE}_${ARCH}"
OUTPUT_DEB="$BASE_DIR/${PKG_NAME}_${VERSION}-${RELEASE}_${ARCH}.deb"

echo "=== Starting Debian Package Build ==="

# 1. Clean previous build environment
rm -rf "$BASE_DIR/build-deb"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/bodhi-update-notifier"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/etc/xdg/autostart"
mkdir -p "$BUILD_DIR/usr/lib/systemd/user"

# 2. Copy scripts to FHS system paths (/usr/bin)
echo "-> Copying binaries..."
cp "$BASE_DIR/bodhi-update-notifier.sh" "$BUILD_DIR/usr/bin/bodhi-update-notifier.sh"
cp "$BASE_DIR/bodhi-update-settings.py" "$BUILD_DIR/usr/bin/bodhi-update-settings.py"
cp "$BASE_DIR/bodhi-update-popup.py" "$BUILD_DIR/usr/bin/bodhi-update-popup.py"
cp "$BASE_DIR/bodhi-update-tray.py" "$BUILD_DIR/usr/bin/bodhi-update-tray.py"

# 3. Set strict file permissions (executable for binaries)
chmod 755 "$BUILD_DIR/usr/bin/bodhi-update-notifier.sh"
chmod 755 "$BUILD_DIR/usr/bin/bodhi-update-settings.py"
chmod 755 "$BUILD_DIR/usr/bin/bodhi-update-popup.py"
chmod 755 "$BUILD_DIR/usr/bin/bodhi-update-tray.py"

# 4. Copy logo asset
if [ -f "$BASE_DIR/bodhi_update_logo.jpg" ]; then
    echo "-> Copying logo assets..."
    cp "$BASE_DIR/bodhi_update_logo.jpg" "$BUILD_DIR/usr/share/bodhi-update-notifier/bodhi_update_logo.jpg"
    chmod 644 "$BUILD_DIR/usr/share/bodhi-update-notifier/bodhi_update_logo.jpg"
fi

# 5. Generate package control metadata file
echo "-> Generating DEBIAN/control file..."
cat <<EOF > "$BUILD_DIR/DEBIAN/control"
Package: $PKG_NAME
Version: $VERSION-$RELEASE
Section: utils
Priority: optional
Architecture: $ARCH
Depends: bash, python3, python3-gi, gir1.2-appindicator3-0.1, zenity, libnotify-bin
Maintainer: Mudhitha <mudhitha@bodhilinux.com>
Description: Lightweight software update utility for Bodhi Linux
 A background notifier that checks for APT, Flatpak, and Snap updates,
 showing a system tray status icon and prompting upgrades using Zenity.
EOF

# 6. Generate systemd user service file (system-wide template)
echo "-> Generating systemd service file..."
cat <<EOF > "$BUILD_DIR/usr/lib/systemd/user/bodhi-update-notifier.service"
[Unit]
Description=Bodhi Linux Software Update Notifier
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/bodhi-update-notifier.sh
Restart=on-failure
RestartSec=10
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF
chmod 644 "$BUILD_DIR/usr/lib/systemd/user/bodhi-update-notifier.service"

# 7. Generate autostart desktop entry for all users
echo "-> Generating global autostart desktop configuration..."
cat <<EOF > "$BUILD_DIR/etc/xdg/autostart/bodhi-update-notifier.desktop"
[Desktop Entry]
Type=Application
Name=Bodhi Update Notifier
Comment=Lightweight background update check & GUI notifier
Exec=/usr/bin/bodhi-update-notifier.sh
Icon=software-update-available
Terminal=false
Categories=System;Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
chmod 644 "$BUILD_DIR/etc/xdg/autostart/bodhi-update-notifier.desktop"

# 8. Generate standard applications desktop launcher
echo "-> Generating application menu launcher..."
cat <<EOF > "$BUILD_DIR/usr/share/applications/bodhi-update-notifier.desktop"
[Desktop Entry]
Type=Application
Name=Bodhi Update Notifier
Comment=Check and install Bodhi software updates
Exec=/usr/bin/bodhi-update-notifier.sh --show-details
Icon=software-update-available
Terminal=false
Categories=System;PackageManager;Utility;
StartupNotify=true
EOF
chmod 644 "$BUILD_DIR/usr/share/applications/bodhi-update-notifier.desktop"

# 9. Generate postinst (post-installation) hook script
echo "-> Creating postinst installer hooks..."
cat <<EOF > "$BUILD_DIR/DEBIAN/postinst"
#!/bin/sh
set -e
if [ "\$1" = "configure" ]; then
    echo "Configuring passwordless apt-get update for silent background checks..."
    echo "%sudo ALL=(ALL) NOPASSWD: /usr/bin/apt-get update" > /etc/sudoers.d/bodhi-update-notifier
    chmod 0440 /etc/sudoers.d/bodhi-update-notifier
fi
EOF
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# 10. Generate prerm (pre-removal) clean-up hook script
echo "-> Creating prerm removal hooks..."
cat <<EOF > "$BUILD_DIR/DEBIAN/prerm"
#!/bin/sh
set -e
if [ "\$1" = "remove" ]; then
    echo "Stopping active update notifier services..."
    pkill -f "bodhi-update-notifier.sh" || true
    pkill -f "bodhi-update-tray.py" || true
    rm -f /tmp/bodhi-update-notifier-*.lock || true
    rm -f /etc/sudoers.d/bodhi-update-notifier || true
fi
EOF
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# 11. Compile building binary into .deb package
echo "-> Compiling files into .deb package using dpkg-deb..."
dpkg-deb --build "$BUILD_DIR" "$OUTPUT_DEB"

# Clean up build tree
rm -rf "$BASE_DIR/build-deb"

echo ""
echo "=================================================="
echo "✔ DEB Package built successfully!"
echo "File: $OUTPUT_DEB"
echo "=================================================="
