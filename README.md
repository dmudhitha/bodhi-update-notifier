<p align="center">
  <img src="bodhi_update_logo.jpg" width="180" alt="Bodhi Update Notifier Logo" style="border-radius: 15px;"/>
</p>

# Bodhi Linux Update Notifier

A modern, lightweight, feature-packed software update manager and system tray notifier built specifically for **Bodhi Linux** (Ubuntu-based Moksha Desktop). It seamlessly tracks, notifies, and upgrades software packages across **APT**, **Flatpak**, and **Snap** packaging systems.

---

## 🌟 Key Features

* **Unified Package Monitoring**: Automatically checks for updates across **APT**, **Flatpak**, and **Snap** repositories.
* **Silent Auto-Updates**: Optional background installation mode that automatically upgrades system and app packages silently without interrupting your workflow.
* **Real-Time Progress Checker (`--check-now`)**: Interactive progress bar dialog providing visual step-by-step status when checking for updates manually.
* **Native GTK3 Preferences Panel (`bodhi-update-settings.py`)**: Sleek graphical control panel to configure update check intervals, source toggles, Quiet Hours, metered data limits, and Silent Auto-Updates.
* **System Tray Integration (`bodhi-update-tray.py`)**: Live PyGObject status icon showing total pending updates with instant right-click menu actions and automatic post-update icon synchronization.
* **Interactive Release Notes & Package Info**: Double-click any update item in the details list to view official changelogs, or rich package descriptions and metadata (`apt-cache show`) for third-party software (e.g. VS Code, Google Chrome, PPAs).
* **Flexible Upgrade Modes**:
  * **Interactive Terminal Mode (Default)**: Executes upgrades in the `terminology` emulator, displaying real-time package outputs and closing automatically when `[Enter]` is pressed.
  * **Zenity Progress Mode**: Graphical progress bar upgrades driven by `pkexec` authentication.
* **Post-Installation Verification**: Automatically verifies remaining updates after installation completes, ensuring 0 errors remain before clearing the update list.
* **Bandwidth & Metered Network Protection**: Detects metered connections via `nmcli` and alerts you before downloading updates over configured download thresholds.
* **Quiet Hours (DND)**: Configurable Quiet Hours interval (e.g., 21:00 to 08:00) during which desktop alerts and popup prompts are suppressed.
* **Self-Healing & Package Manager Repair (`--repair`)**: One-click diagnostic tool to clear stale lock files (`/var/lib/dpkg/lock-frontend`) and fix broken dependencies.

---

## 📂 File Architecture

* **`bodhi-update-notifier.sh`**: Core Bash daemon engine, CLI router, and GUI window launcher.
* **`bodhi-update-popup.py`**: Native GTK3 update notification popup dialog with direct action triggers.
* **`bodhi-update-settings.py`**: Native GTK3 preferences application (`--settings`).
* **`bodhi-update-tray.py`**: PyGObject AppIndicator companion applet for system tray monitoring.
* **`build-deb.sh`**: Automated Debian package compilation script (`.deb`).
* **`install.sh`**: User-space installer script.
* **`uninstall.sh`**: Cleaner script for user-space installation.
* **`.gitignore`**: Git configuration ignoring compiled `.deb` packages and build artifacts.

---

## ⚙️ CLI Flags & Commands

Settings are stored in `~/.config/bodhi-update-notifier/config.conf`. You can invoke the utility using the following options:

| Flag | Description |
| :--- | :--- |
| *(none)* | Launches the background update checker daemon |
| `--check-now` | Runs an interactive update check with a real-time progress bar |
| `--show-details` | Displays the spreadsheet list of available updates & release notes |
| `--install-now` | Triggers immediate package upgrade (Terminal or Zenity mode) |
| `--settings` | Opens the GTK3 Update Manager Preferences panel |
| `--repair` | Executes self-healing diagnostic routines to clear stuck APT locks |
| `--help` | Displays CLI usage instructions |

---

## 🚀 Installation

### Option A: Install via `.deb` Package (Recommended)
Building and installing the `.deb` package installs binaries to `/usr/bin/`, sets up system menu shortcuts under **System Tools**, configures user systemd services, and grants unprivileged background index refreshes via `/etc/sudoers.d/bodhi-update-notifier`.

```bash
# 1. Build the Debian package
/home/mudhitha/System/bodhi-update-notifier/build-deb.sh

# 2. Install the package
sudo apt install /home/mudhitha/System/bodhi-update-notifier/bodhi-update-notifier_1.0-1_all.deb
```

### Option B: Local User-Space Setup (`install.sh`)
If you prefer running without root packaging:

1. Grant passwordless `apt-get update` rights for background checking:
   ```bash
   echo "%sudo ALL=(ALL) NOPASSWD: /usr/bin/apt-get update" | sudo tee /etc/sudoers.d/bodhi-update-notifier >/dev/null && sudo chmod 0440 /etc/sudoers.d/bodhi-update-notifier
   ```
2. Execute local installer:
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

## 📊 Monitoring & Logs

* **Check background service status**:
  ```bash
  systemctl --user status bodhi-update-notifier.service
  ```
* **View real-time daemon logs**:
  ```bash
  tail -f ~/.local/share/bodhi-update-notifier/notifier.log
  ```
