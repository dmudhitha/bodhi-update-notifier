#!/usr/bin/env python3

import os
import sys
import subprocess
import signal
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, GLib
from gi.repository import AppIndicator3 as appindicator

# Paths
SHARE_DIR = os.path.expanduser("~/.local/share/bodhi-update-notifier")
LOCK_FILE = f"/tmp/bodhi-update-notifier-{os.getuid()}.lock"
UPDATES_LIST_FILE = os.path.join(SHARE_DIR, "updates.list")
LOG_FILE = os.path.join(SHARE_DIR, "notifier.log")

# Get path to notifier script relative to this file
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NOTIFIER_PATH = os.path.join(SCRIPT_DIR, "bodhi-update-notifier.sh")

class BodhiUpdateIndicator:
    def __init__(self):
        self.indicator = appindicator.Indicator.new(
            "bodhi-update-notifier-indicator",
            "system-software-update", # default icon
            appindicator.IndicatorCategory.SYSTEM_SERVICES
        )
        self.indicator.set_status(appindicator.IndicatorStatus.ACTIVE)
        
        # Build menu
        self.menu = Gtk.Menu()
        
        # Show Details item
        self.item_details = Gtk.MenuItem(label="Show Available Updates")
        self.item_details.connect("activate", self.on_show_details)
        self.menu.append(self.item_details)
        
        # Install Updates item
        self.item_install = Gtk.MenuItem(label="Install Updates Now")
        self.item_install.connect("activate", self.on_install_updates)
        self.menu.append(self.item_install)
        
        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # Check Now item
        self.item_check = Gtk.MenuItem(label="Check for Updates Now")
        self.item_check.connect("activate", self.on_check_now)
        self.menu.append(self.item_check)
        
        # Repair Package Manager item
        self.item_repair = Gtk.MenuItem(label="Repair Package Manager")
        self.item_repair.connect("activate", self.on_repair)
        self.menu.append(self.item_repair)
        
        # Update Preferences item
        self.item_prefs = Gtk.MenuItem(label="Update Preferences...")
        self.item_prefs.connect("activate", self.on_preferences)
        self.menu.append(self.item_prefs)
        
        # View Logs item
        self.item_logs = Gtk.MenuItem(label="View Log File")
        self.item_logs.connect("activate", self.on_view_logs)
        self.menu.append(self.item_logs)
        
        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())
        
        # Exit item
        self.item_exit = Gtk.MenuItem(label="Exit")
        self.item_exit.connect("activate", self.on_exit)
        self.menu.append(self.item_exit)
        
        self.menu.show_all()
        self.indicator.set_menu(self.menu)
        
        # Initial status check
        self.update_ui()
        
        # Periodically refresh the icon status every 5 seconds
        GLib.timeout_add_seconds(5, self.update_ui)

    def get_bash_pid(self):
        if os.path.exists(LOCK_FILE):
            try:
                with open(LOCK_FILE, 'r') as f:
                    pid = int(f.read().strip())
                    return pid
            except Exception:
                pass
        return None

    def parse_updates(self):
        apt_count = 0
        flatpak_count = 0
        snap_count = 0
        total_count = 0
        
        if os.path.exists(UPDATES_LIST_FILE):
            try:
                with open(UPDATES_LIST_FILE, 'r') as f:
                    for line in f:
                        parts = line.strip().split('|')
                        if len(parts) >= 1 and parts[0]:
                            source = parts[0].upper()
                            if source == "APT":
                                apt_count += 1
                            elif source == "FLATPAK":
                                flatpak_count += 1
                            elif source == "SNAP":
                                snap_count += 1
                            total_count += 1
            except Exception:
                pass
        return total_count, apt_count, flatpak_count, snap_count

    def update_ui(self):
        total, apt, flat, snap = self.parse_updates()
        
        if total > 0:
            # Change icon to signify pending updates
            self.indicator.set_icon_full("software-update-available", f"{total} Updates Available")
            
            # Enable actions
            self.item_details.set_sensitive(True)
            self.item_install.set_sensitive(True)
            self.item_details.set_label(f"Show Available Updates ({total})")
        else:
            # Change icon to signify system is synchronized (up to date)
            self.indicator.set_icon_full("emblem-synchronized", "System Up to Date")
            
            # Disable actions
            self.item_details.set_sensitive(False)
            self.item_install.set_sensitive(False)
            self.item_details.set_label("Show Available Updates (0)")
            
        return True

    def on_show_details(self, widget):
        # Trigger show details directly by invoking the bash script flag
        subprocess.Popen([NOTIFIER_PATH, "--show-details"])

    def on_install_updates(self, widget):
        # Trigger interactive/graphical installation
        subprocess.Popen([NOTIFIER_PATH, "--install-now"])

    def on_check_now(self, widget):
        pid = self.get_bash_pid()
        if pid:
            try:
                # Send SIGUSR1 to awake the background bash process from sleep
                os.kill(pid, signal.SIGUSR1)
                # Show standard temporary zenity notification
                subprocess.Popen(["zenity", "--notification", "--text=Checking for updates...", "--timeout=2"])
            except Exception:
                pass
        else:
            # If the daemon is dead, start it up again
            subprocess.Popen([NOTIFIER_PATH])

    def on_repair(self, widget):
        # Launch package manager diagnostics and repair
        subprocess.Popen([NOTIFIER_PATH, "--repair"])

    def on_preferences(self, widget):
        # Launch settings GUI
        subprocess.Popen([NOTIFIER_PATH, "--settings"])

    def on_view_logs(self, widget):
        # Open log in default viewer/editor
        editor = os.environ.get("VISUAL", os.environ.get("EDITOR", "xdg-open"))
        subprocess.Popen([editor, LOG_FILE])

    def on_exit(self, widget):
        Gtk.main_quit()

def main():
    # Handle KeyboardInterrupt cleanly
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    # Initialize the tray applet
    BodhiUpdateIndicator()
    Gtk.main()

if __name__ == "__main__":
    main()
