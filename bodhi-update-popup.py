#!/usr/bin/env python3
"""
Bodhi Update Notifier - Graphical Update Prompt Popup
Native GTK3 dialog offering Install Now, Show Details, and Remind Later actions.
"""

import sys
import os
import subprocess
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NOTIFIER_PATH = os.path.join(SCRIPT_DIR, "bodhi-update-notifier.sh")
if not os.path.exists(NOTIFIER_PATH):
    NOTIFIER_PATH = "/usr/bin/bodhi-update-notifier.sh"

class UpdateNotificationDialog(Gtk.Window):
    def __init__(self, total_count="1", extra_warning=""):
        super().__init__(title="Bodhi Update Utility")
        self.set_border_width(18)
        self.set_default_size(480, 190)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)
        self.set_keep_above(True)

        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        self.add(main_box)

        # Left Icon
        icon_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        icon = Gtk.Image.new_from_icon_name("software-update-available", Gtk.IconSize.DIALOG)
        icon_box.pack_start(icon, False, False, 5)
        main_box.pack_start(icon_box, False, False, 0)

        # Right Content Area
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        main_box.pack_start(content_box, True, True, 0)

        # Title Label
        lbl_title = Gtk.Label()
        lbl_title.set_markup("<b><span size='large'>System Updates Available</span></b>")
        lbl_title.set_alignment(0, 0.5)
        content_box.pack_start(lbl_title, False, False, 0)

        # Message Body
        msg_text = f"There are <b>{total_count}</b> software updates ready for your Bodhi Linux system."
        if extra_warning:
            msg_text += f"\n\n{extra_warning}"
        msg_text += "\n\nWould you like to install them now?"

        lbl_msg = Gtk.Label()
        lbl_msg.set_line_wrap(True)
        lbl_msg.set_alignment(0, 0.5)
        lbl_msg.set_markup(msg_text)
        content_box.pack_start(lbl_msg, True, True, 0)

        # Action Buttons Box
        btn_box = Gtk.ButtonBox(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_layout(Gtk.ButtonBoxStyle.END)
        content_box.pack_end(btn_box, False, False, 0)

        btn_later = Gtk.Button(label="Remind Me Later")
        btn_later.connect("clicked", self.on_remind_later)
        btn_box.add(btn_later)

        btn_details = Gtk.Button(label="Show Details")
        btn_details.connect("clicked", self.on_show_details)
        btn_box.add(btn_details)

        btn_install = Gtk.Button(label="Install Now")
        btn_install.get_style_context().add_class("suggested-action")
        btn_install.connect("clicked", self.on_install_now)
        btn_box.add(btn_install)

    def on_install_now(self, widget):
        self.destroy()
        subprocess.Popen([NOTIFIER_PATH, "--install-now"])
        Gtk.main_quit()

    def on_show_details(self, widget):
        self.destroy()
        subprocess.Popen([NOTIFIER_PATH, "--show-details"])
        Gtk.main_quit()

    def on_remind_later(self, widget):
        self.destroy()
        Gtk.main_quit()

if __name__ == '__main__':
    count = sys.argv[1] if len(sys.argv) > 1 else "1"
    warning = sys.argv[2] if len(sys.argv) > 2 else ""
    win = UpdateNotificationDialog(total_count=count, extra_warning=warning)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
