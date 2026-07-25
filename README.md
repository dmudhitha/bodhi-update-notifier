<p align="center">
  <img src="bodhi_update_logo.jpg" width="180" alt="Bodhi Update Notifier Logo" style="border-radius: 15px;"/>
</p>

# Bodhi Linux Update Notifier

A lightweight, background software update utility designed specifically for Bodhi Linux (Ubuntu-based). It runs silently in the background, periodically checks for system updates, notifies the user via a clean Zenity GUI dialog, and executes the package upgrades interactively inside the Terminology terminal emulator.

---

## 🌟 Features

* **Silent & Resource Efficient**: Runs in the background with zero idle CPU load.
* **Unified Package Checks**: Automatically checks for updates across **APT**, **Flatpak**, and **Snap** packaging systems.
* **Modern Settings Panel**: A built-in graphical preferences panel to customize the checker's behaviors.
* **Interactive Release Notes**: Double-clicking a package in the updates list fetches and shows the official changelog/release notes.
* **Metered Bandwidth Warnings**: Automatically checks if your current network connection is metered, warning you before downloading large updates.
* **Self-Healing & Repair**: Detects and offers to resolve package manager lock conflicts (e.g., stuck lock files).
* **DND / Quiet Hours**: Configurable Quiet Hours during which notification alerts are suppressed, updating silently in the tray.
* **Desktop Notifications**: Uses `notify-send` for transient system notifications.

---

## 📂 Files Included

* **`bodhi-update-notifier.sh`**: The main Bash command router (Daemon / GUI / Diagnostics).
* **`bodhi-update-tray.py`**: Python PyGObject companion applet displaying status in the system tray.
* **`bodhi-update-notifier.service`**: Systemd user service configuration file.
* **`bodhi-update-notifier.desktop`**: Desktop autostart configuration file.

---

## ⚙️ Configuration & GUI Commands

Settings are saved in `~/.config/bodhi-update-notifier/config.conf`. You can customize them using the GUI or command-line:

* **Show Update Preferences (Settings Dashboard)**:
  ```bash
  /home/mudhitha/System/bodhi-update-notifier/bodhi-update-notifier.sh --settings
  ```
* **Repair Package Manager (Resolve Locks)**:
  ```bash
  /home/mudhitha/System/bodhi-update-notifier/bodhi-update-notifier.sh --repair
  ```
* **Show Update List (Changelogs)**:
  ```bash
  /home/mudhitha/System/bodhi-update-notifier/bodhi-update-notifier.sh --show-details
  ```

---

## 🚀 Setup & Installation

### Option A: Install via `.deb` Package (Recommended)
Installing the `.deb` package is the simplest and most automated method. It automatically installs binaries to `/usr/bin/`, sets up the system tools menu shortcut, and configures `/etc/sudoers.d/bodhi-update-notifier` so the background daemon can fetch new package lists silently without asking for a password.

```bash
sudo apt install /home/mudhitha/System/bodhi-update-notifier/bodhi-update-notifier_1.0-1_all.deb
```

### Option B: Local User-Space Setup (`install.sh`)
If you prefer running the script strictly from your user home directory:

1. Allow silent background package list refreshes:
   ```bash
   echo "%sudo ALL=(ALL) NOPASSWD: /usr/bin/apt-get update" | sudo tee /etc/sudoers.d/bodhi-update-notifier >/dev/null && sudo chmod 0440 /etc/sudoers.d/bodhi-update-notifier
   ```
2. Run the local installer script:
   ```bash
   /home/mudhitha/System/bodhi-update-notifier/install.sh
   ```

---

## 🗑️ Uninstallation

* **If installed via `.deb` package**:
  ```bash
  sudo apt remove bodhi-update-notifier
  ```
* **If installed via `install.sh`**:
  ```bash
  /home/mudhitha/System/bodhi-update-notifier/uninstall.sh
  ```

---

## 📊 Management & Logs

* **Check service status**:
  ```bash
  systemctl --user status bodhi-update-notifier.service
  ```
* **View update activity log**:
  ```bash
  tail -f ~/.local/share/bodhi-update-notifier/notifier.log
  ```
