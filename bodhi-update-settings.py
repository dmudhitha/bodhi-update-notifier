#!/usr/bin/env python3

import os
import sys
import signal
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

# Configuration paths
CONFIG_FILE = os.path.expanduser("~/.config/bodhi-update-notifier/config.conf")
LOCK_FILE = "/tmp/bodhi-update-notifier-" + str(os.getuid()) + ".lock"

class SettingsWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Update Manager Preferences")
        self.set_border_width(15)
        self.set_default_size(450, 420)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        # Default config values
        self.config = {
            "CHECK_INTERVAL": "4h",
            "PROGRESS_MODE": "terminal",
            "CHECK_APT": "true",
            "CHECK_FLATPAK": "true",
            "CHECK_SNAP": "true",
            "ENABLE_QUIET_HOURS": "false",
            "QUIET_HOURS_START": "21:00",
            "QUIET_HOURS_END": "08:00",
            "METERED_WARNING": "true",
            "METERED_THRESHOLD_MB": "100"
        }
        
        self.load_config()
        self.build_ui()
        
    def load_config(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or '=' not in line:
                            continue
                        key, val = line.split('=', 1)
                        key = key.strip()
                        val = val.strip().strip('"').strip("'")
                        if key in self.config:
                            self.config[key] = val
            except Exception as e:
                print(f"Error loading config: {e}")

    def save_config(self):
        # Read values from UI widgets
        self.config["CHECK_INTERVAL"] = self.entry_interval.get_text().strip()
        self.config["PROGRESS_MODE"] = "terminal" if self.combo_ui.get_active() == 0 else "zenity"
        self.config["CHECK_APT"] = "true" if self.check_apt.get_active() else "false"
        self.config["CHECK_FLATPAK"] = "true" if self.check_flatpak.get_active() else "false"
        self.config["CHECK_SNAP"] = "true" if self.check_snap.get_active() else "false"
        self.config["ENABLE_QUIET_HOURS"] = "true" if self.check_qh.get_active() else "false"
        self.config["QUIET_HOURS_START"] = self.entry_qh_start.get_text().strip()
        self.config["QUIET_HOURS_END"] = self.entry_qh_end.get_text().strip()
        self.config["METERED_WARNING"] = "true" if self.check_metered.get_active() else "false"
        self.config["METERED_THRESHOLD_MB"] = self.entry_metered_size.get_text().strip()
        
        # Write to file
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        try:
            with open(CONFIG_FILE, 'w') as f:
                for key, val in self.config.items():
                    f.write(f'{key}="{val}"\n')
            
            # Send SIGUSR1 to background daemon
            if os.path.exists(LOCK_FILE):
                with open(LOCK_FILE, 'r') as lf:
                    pid = int(lf.read().strip())
                    os.kill(pid, signal.SIGUSR1)
        except Exception as e:
            print(f"Error saving config: {e}")
            
        self.destroy()
        Gtk.main_quit()

    def build_ui(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)
        
        # Header Label
        header = Gtk.Label()
        header.set_markup("<b><span size='large'>Bodhi Update Notifier Preferences</span></b>")
        header.set_alignment(0, 0.5)
        vbox.pack_start(header, False, False, 5)
        
        # Form Grid
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        vbox.pack_start(grid, True, True, 5)
        
        row = 0
        
        # 1. Check Interval
        lbl_interval = Gtk.Label(label="Check Interval (e.g. 4h, 30m):")
        lbl_interval.set_alignment(0, 0.5)
        grid.attach(lbl_interval, 0, row, 1, 1)
        
        self.entry_interval = Gtk.Entry()
        self.entry_interval.set_text(self.config["CHECK_INTERVAL"])
        grid.attach(self.entry_interval, 1, row, 1, 1)
        row += 1
        
        # 2. Installation UI Mode
        lbl_ui = Gtk.Label(label="Installation UI Mode:")
        lbl_ui.set_alignment(0, 0.5)
        grid.attach(lbl_ui, 0, row, 1, 1)
        
        self.combo_ui = Gtk.ComboBoxText()
        self.combo_ui.append_text("Terminology Terminal (Interactive)")
        self.combo_ui.append_text("Zenity GUI Progress Bar (Silent)")
        if self.config["PROGRESS_MODE"] == "terminal":
            self.combo_ui.set_active(0)
        else:
            self.combo_ui.set_active(1)
        grid.attach(self.combo_ui, 1, row, 1, 1)
        row += 1
        
        # 3. Repository check toggles
        lbl_repos = Gtk.Label(label="Enable Package Sources:")
        lbl_repos.set_alignment(0, 0.5)
        grid.attach(lbl_repos, 0, row, 1, 1)
        
        repo_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.check_apt = Gtk.CheckButton(label="System Packages (APT)")
        self.check_apt.set_active(self.config["CHECK_APT"] == "true")
        self.check_flatpak = Gtk.CheckButton(label="Flatpak Updates")
        self.check_flatpak.set_active(self.config["CHECK_FLATPAK"] == "true")
        self.check_snap = Gtk.CheckButton(label="Snap Updates")
        self.check_snap.set_active(self.config["CHECK_SNAP"] == "true")
        
        repo_box.pack_start(self.check_apt, False, False, 0)
        repo_box.pack_start(self.check_flatpak, False, False, 0)
        repo_box.pack_start(self.check_snap, False, False, 0)
        grid.attach(repo_box, 1, row, 1, 1)
        row += 1
        
        # 4. Quiet Hours
        lbl_qh = Gtk.Label(label="Quiet Hours (DND):")
        lbl_qh.set_alignment(0, 0.5)
        grid.attach(lbl_qh, 0, row, 1, 1)
        
        qh_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.check_qh = Gtk.CheckButton(label="Enable Quiet Hours")
        self.check_qh.set_active(self.config["ENABLE_QUIET_HOURS"] == "true")
        
        time_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.entry_qh_start = Gtk.Entry()
        self.entry_qh_start.set_width_chars(5)
        self.entry_qh_start.set_text(self.config["QUIET_HOURS_START"])
        self.entry_qh_end = Gtk.Entry()
        self.entry_qh_end.set_width_chars(5)
        self.entry_qh_end.set_text(self.config["QUIET_HOURS_END"])
        
        time_box.pack_start(self.entry_qh_start, False, False, 0)
        time_box.pack_start(Gtk.Label(label=" to "), False, False, 0)
        time_box.pack_start(self.entry_qh_end, False, False, 0)
        
        qh_box.pack_start(self.check_qh, False, False, 0)
        qh_box.pack_start(time_box, False, False, 0)
        grid.attach(qh_box, 1, row, 1, 1)
        row += 1
        
        # 5. Metered Network warning
        lbl_metered = Gtk.Label(label="Metered Network:")
        lbl_metered.set_alignment(0, 0.5)
        grid.attach(lbl_metered, 0, row, 1, 1)
        
        metered_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.check_metered = Gtk.CheckButton(label="Warn on Metered Connection")
        self.check_metered.set_active(self.config["METERED_WARNING"] == "true")
        
        size_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.entry_metered_size = Gtk.Entry()
        self.entry_metered_size.set_width_chars(6)
        self.entry_metered_size.set_text(self.config["METERED_THRESHOLD_MB"])
        
        size_box.pack_start(Gtk.Label(label="Warning Limit: "), False, False, 0)
        size_box.pack_start(self.entry_metered_size, False, False, 0)
        size_box.pack_start(Gtk.Label(label=" MB"), False, False, 0)
        
        metered_box.pack_start(self.check_metered, False, False, 0)
        metered_box.pack_start(size_box, False, False, 0)
        grid.attach(metered_box, 1, row, 1, 1)
        row += 1
        
        # Action Buttons
        button_box = Gtk.ButtonBox(spacing=10)
        button_box.set_layout(Gtk.ButtonBoxStyle.END)
        vbox.pack_end(button_box, False, False, 5)
        
        btn_cancel = Gtk.Button(label="Cancel")
        btn_cancel.connect("clicked", lambda w: self.on_cancel())
        button_box.add(btn_cancel)
        
        btn_save = Gtk.Button(label="Save Settings")
        btn_save.get_style_context().add_class("suggested-action")
        btn_save.connect("clicked", lambda w: self.save_config())
        button_box.add(btn_save)
        
    def on_cancel(self):
        self.destroy()
        Gtk.main_quit()

def main():
    win = SettingsWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
