import gi
from fabric.widgets.box import Box
from fabric.widgets.label import Label
from fabric.widgets.stack import Stack
import time

import config.data as data
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

import modules.icons as icons
from modules.mixer import Mixer
from modules.wallpapers import WallpaperSelector
from modules.widgets import Widgets

class Dashboard(Box):
    def __init__(self, **kwargs):
        super().__init__(
            name="dashboard",
            orientation="v",
            spacing=8,
            h_align="center",
            v_align="center",
            h_expand=True,
            visible=True,
            all_visible=True,
        )
        print(f"[{time.strftime('%H:%M:%S')}] Initializing Dashboard")
        self.notch = kwargs["notch"]

        # Initialize child widgets
        self.widgets = Widgets(notch=self.notch)
        self.wallpapers = WallpaperSelector()
        self.mixer = Mixer()

        # Initialize stack with no transitions
        self.stack = Stack(
            name="stack",
            transition_type="none",  # Disable transitions to reduce lag
            transition_duration=0,
            v_expand=True,
            v_align="fill",
            h_expand=True,
            h_align="fill",
        )
        self.stack.set_homogeneous(False)

        # Initialize switcher
        self.switcher = Gtk.StackSwitcher(name="switcher", spacing=8)
        self.switcher.set_stack(self.stack)
        self.switcher.set_hexpand(True)
        self.switcher.set_homogeneous(True)
        self.switcher.set_can_focus(True)

        # Add children to stack (excluding Pins and Kanban)
        self.stack.add_titled(self.widgets, "widgets", "Widgets")
        self.stack.add_titled(self.wallpapers, "wallpapers", "Wallpapers")
        self.stack.add_titled(self.mixer, "mixer", "Mixer")

        self.stack.connect("notify::visible-child", self.on_visible_child_changed)
        self.add(self.switcher)
        self.add(self.stack)

        # Setup icons only if needed
        if data.PANEL_THEME == "Panel" and (
            data.BAR_POSITION in ["Left", "Right"] or data.PANEL_POSITION in ["Start", "End"]
        ):
            GLib.idle_add(self._setup_switcher_icons)
            print(f"[{time.strftime('%H:%M:%S')}] Scheduled switcher icons setup")

        # Show only necessary components
        self.switcher.show()
        self.stack.show()
        self.stack.get_visible_child().show()

    def _setup_switcher_icons(self):
        print(f"[{time.strftime('%H:%M:%S')}] Setting up switcher icons")
        icon_details_map = {
            "Widgets": {"icon": icons.widgets, "name": "widgets"},
            "Wallpapers": {"icon": icons.wallpapers, "name": "wallpapers"},
            "Mixer": {"icon": icons.speaker, "name": "mixer"},
        }
        self.switcher.freeze_notify()
        buttons = self.switcher.get_children()
        for btn in buttons:
            if isinstance(btn, Gtk.ToggleButton):
                for child in btn.get_children():
                    if isinstance(child, Gtk.Label) and not child.get_name().startswith("switcher-icon"):
                        label_text = child.get_text()
                        if label_text in icon_details_map:
                            details = icon_details_map[label_text]
                            btn.remove(child)
                            new_icon_label = Label(name=f"switcher-icon-{details['name']}", markup=details["icon"])
                            btn.add(new_icon_label)
                            new_icon_label.show()
                            print(f"[{time.strftime('%H:%M:%S')}] Replaced label with icon for {label_text}")
                            break
        self.switcher.thaw_notify()
        return GLib.SOURCE_REMOVE

    def on_visible_child_changed(self, stack, param):
        print(f"[{time.strftime('%H:%M:%S')}] Dashboard visible child changed to {stack.get_visible_child_name()}")
        visible = stack.get_visible_child()
        if visible == self.wallpapers and self.wallpapers.search_entry.get_text():
            self.wallpapers.search_entry.set_text("")
            self.wallpapers.search_entry.grab_focus()

    def go_to_next_child(self):
        print(f"[{time.strftime('%H:%M:%S')}] Switching to next dashboard child")
        children = self.stack.get_children()
        current = self.stack.get_visible_child()
        current_index = children.index(current) if current in children else 0
        next_index = (current_index + 1) % len(children)
        self.stack.set_visible_child(children[next_index])

    def go_to_previous_child(self):
        print(f"[{time.strftime('%H:%M:%S')}] Switching to previous dashboard child")
        children = self.stack.get_children()
        current = self.stack.get_visible_child()
        current_index = children.index(current) if current in children else 0
        prev_index = (current_index - 1 + len(children)) % len(children)
        self.stack.set_visible_child(children[prev_index])

    def go_to_section(self, section_name):
        print(f"[{time.strftime('%H:%M:%S')}] Going to dashboard section: {section_name}")
        if section_name in ["widgets", "wallpapers", "mixer"]:
            self.stack.set_visible_child_name(section_name)
