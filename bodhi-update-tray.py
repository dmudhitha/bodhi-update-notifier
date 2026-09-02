#!/usr/bin/env python3

import os
import sys
import time
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
SNOOZE_FILE = os.path.join(SHARE_DIR, "snooze.until")

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
        
        # Snooze Status / Cancel Snooze item
        self.item_snooze = Gtk.MenuItem(label="Reminder Snoozed - Cancel")
        self.item_snooze.connect("activate", self.on_cancel_snooze)
        self.menu.append(self.item_snooze)
        self.item_snooze.set_no_show_all(True)
        
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

    def check_snooze(self):
        if os.path.exists(SNOOZE_FILE):
            try:
                with open(SNOOZE_FILE, 'r') as f:
                    snooze_until = int(f.read().strip())
                now = int(time.time())
                if snooze_until > now:
                    return max(1, (snooze_until - now) // 60)
                else:
                    os.remove(SNOOZE_FILE)
            except Exception:
                pass
        return 0

    def update_ui(self):
        total, apt, flat, snap = self.parse_updates()
        mins_left = self.check_snooze()
        
        if total > 0:
            # Change icon to signify pending updates
            self.indicator.set_icon_full("software-update-available", f"{total} Updates Available")
            
            # Enable actions
            self.item_details.set_sensitive(True)
            self.item_install.set_sensitive(True)
            self.item_details.set_label(f"Show Available Updates ({total})")
            
            if mins_left > 0:
                if mins_left >= 60:
                    hrs = mins_left // 60
                    rem_m = mins_left % 60
                    time_str = f"{hrs}h {rem_m}m" if rem_m else f"{hrs}h"
                else:
                    time_str = f"{mins_left}m"
                self.item_snooze.set_label(f"Reminder Snoozed ({time_str} left) - Cancel")
                self.item_snooze.show()
            else:
                self.item_snooze.hide()
        else:
            # Change icon to signify system is synchronized (up to date)
            self.indicator.set_icon_full("emblem-synchronized", "System Up to Date")
            
            # Disable actions
            self.item_details.set_sensitive(False)
            self.item_install.set_sensitive(False)
            self.item_details.set_label("Show Available Updates (0)")
            self.item_snooze.hide()
            
        return True

    def on_cancel_snooze(self, widget):
        if os.path.exists(SNOOZE_FILE):
            try:
                os.remove(SNOOZE_FILE)
            except Exception:
                pass
        subprocess.Popen([
            "notify-send", "-i", "software-update-available",
            "Update Snooze Cancelled",
            "Update notifications are resumed."
        ])
        pid = self.get_bash_pid()
        if pid:
            try:
                os.kill(pid, signal.SIGUSR1)
            except Exception:
                pass
        self.update_ui()

    def on_show_details(self, widget):
        # Trigger show details directly by invoking the bash script flag
        subprocess.Popen([NOTIFIER_PATH, "--show-details"])

    def on_install_updates(self, widget):
        # Trigger interactive/graphical installation
        subprocess.Popen([NOTIFIER_PATH, "--install-now"])

    def on_check_now(self, widget):
        # Trigger interactive progress check in bash
        subprocess.Popen([NOTIFIER_PATH, "--check-now"])

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
