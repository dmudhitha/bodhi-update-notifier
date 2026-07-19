<p align="center">
  <img src="bodhi_update_logo.jpg" width="180" alt="Bodhi Update Notifier Logo" style="border-radius: 15px;"/>
</p>

# Bodhi Linux Update Notifier

A lightweight, background software update utility designed specifically for Bodhi Linux (Ubuntu-based). It runs silently in the background, periodically checks for system updates, notifies the user via a clean Zenity GUI dialog, and executes the package upgrades interactively inside the Terminology terminal emulator.

---

## 🌟 Features

* **Silent & Resource Efficient**: Minimal CPU/memory footprints. Runs in the background and sleeps between check intervals.
* **Smart Internet Check**: Verifies internet connectivity before checking, retrying after a short sleep if offline.
* **Robust Cache Updating**: Silently tries to refresh package lists via `apt-get update`. Falls back gracefully to checking the existing local cache if passwordless sudo is not configured.
* **Modern Zenity Prompts**: Uses GTK-based popup boxes with bold titles and action buttons to prompt the user.
* **Interactive Terminal Upgrades**: Opens the `terminology` terminal (the default Bodhi terminal) for interactive upgrades. This ensures that any package configuration prompts can be safely answered.
* **Graphical Progress Fallback**: Includes a configurable GUI-only progress bar option using `pkexec` and `zenity --progress`.
* **Lock Protection**: Employs a process lock-file to prevent redundant notifications or overlapping checks.

---

## 📂 Files Included

* **`bodhi-update-notifier.sh`**: The main Bash script doing the checking, logging, and GUI rendering.
* **`bodhi-update-notifier.service`**: Systemd user service configuration file.
* **`bodhi-update-notifier.desktop`**: X11/Desktop autostart launcher configuration file.

---

## ⚙️ Configuration

Open `bodhi-update-notifier.sh` and customize these variables at the top:

```bash
CHECK_INTERVAL="4h"       # Check interval (e.g., 30m, 4h, 12h, 1d)
PROGRESS_MODE="terminal"  # "terminal" (interactive upgrade) or "zenity" (progress bar GUI)
LOG_FILE="$HOME/.local/share/bodhi-update-notifier/notifier.log"
```

---

## 🚀 Quick Setup & Installation

### 1. Allow Silent Background Checks (Recommended)
Allow the background script to refresh package indexes without prompting you for a password every cycle:
```bash
sudo visudo /etc/sudoers.d/bodhi-update-notifier
```
Add the following line at the bottom, then save and close:
```text
%sudo ALL=(ALL) NOPASSWD: /usr/bin/apt-get update
```

### 2. Run the Installer
Run the installation script to copy binaries, register settings, and enable both the Systemd user service and Desktop autostart configurations automatically:
```bash
/home/mudhitha/System/bodhi-update-notifier/install.sh
```

---

## 🗑️ Uninstallation

If you wish to cleanly remove the application and stop the background services, simply run:
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
