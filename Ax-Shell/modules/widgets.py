import gi
import time

gi.require_version("Gtk", "3.0")
from fabric.widgets.box import Box
from fabric.widgets.stack import Stack

import config.data as data
from modules.bluetooth import BluetoothConnections
from modules.buttons import Buttons
from modules.calendar import Calendar
from modules.controls import ControlSliders
from modules.metrics import Metrics
from modules.network import NetworkConnections
from modules.notifications import NotificationHistory
from modules.player import Player

class Widgets(Box):
    def __init__(self, **kwargs):
        super().__init__(
            name="dash-widgets",
            h_align="fill",
            v_align="fill",
            h_expand=True,
            v_expand=True,
            visible=True,
            all_visible=True,
        )
        print(f"[{time.strftime('%H:%M:%S')}] Initializing Widgets")

        vertical_layout = False
        if data.PANEL_THEME == "Panel" and (
            data.BAR_POSITION in ["Left", "Right"]
            or data.PANEL_POSITION in ["Start", "End"]
        ):
            vertical_layout = True

        calendar_view_mode = "week" if vertical_layout else "month"

        self.calendar = Calendar(view_mode=calendar_view_mode)
        print(f"[{time.strftime('%H:%M:%S')}] Initialized Calendar (view_mode: {calendar_view_mode})")

        self.notch = kwargs["notch"]

        self.buttons = Buttons(widgets=self)
        print(f"[{time.strftime('%H:%M:%S')}] Initialized Buttons")
        self.bluetooth = BluetoothConnections(widgets=self)
        print(f"[{time.strftime('%H:%M:%S')}] Initialized BluetoothConnections")

        self.box_1 = Box(
            name="box-1",
            h_expand=True,
            v_expand=True,
        )
        self.box_2 = Box(
            name="box-2",
            h_expand=True,
            v_expand=True,
        )
        self.box_3 = Box(
            name="box-3",
            v_expand=True,
        )

        self.controls = ControlSliders()
        print(f"[{time.strftime('%H:%M:%S')}] Initialized ControlSliders")

        self.player = Player()
        print(f"[{time.strftime('%H:%M:%S')}] Initialized Player")

        self.metrics = Metrics()
        print(f"[{time.strftime('%H:%M:%S')}] Initialized Metrics")

        self.notification_history = NotificationHistory()
        print(f"[{time.strftime('%H:%M:%S')}] Initialized NotificationHistory")

        self.network_connections = NetworkConnections(widgets=self)
        print(f"[{time.strftime('%H:%M:%S')}] Initialized NetworkConnections")

        self.applet_stack = Stack(
            h_expand=True,
            v_expand=True,
            transition_type="none",  # Disable transitions to reduce lag
            transition_duration=0,
            children=[
                self.notification_history,
                self.network_connections,
                self.bluetooth,
            ],
        )
        print(f"[{time.strftime('%H:%M:%S')}] Initialized applet_stack")

        self.applet_stack.connect("notify::visible-child", self.on_applet_stack_changed)

        self.applet_stack_box = Box(
            name="applet-stack",
            h_expand=True,
            v_expand=True,
            h_align="fill",
            children=[
                self.applet_stack,
            ],
        )

        if not vertical_layout:
            self.children_1 = [
                Box(
                    name="container-sub-1",
                    h_expand=True,
                    v_expand=True,
                    spacing=8,
                    children=[
                        self.calendar,
                        self.applet_stack_box,
                    ],
                ),
                self.metrics,
            ]
        else:
            self.children_1 = [
                self.applet_stack_box,
                self.calendar,  # Weekly view when vertical
                self.player,
            ]

        self.container_1 = Box(
            name="container-1",
            h_expand=True,
            v_expand=True,
            orientation="h" if not vertical_layout else "v",
            spacing=8,
            children=self.children_1,
        )

        self.container_2 = Box(
            name="container-2",
            h_expand=True,
            v_expand=True,
            orientation="v",
            spacing=8,
            children=[
                self.buttons,
                self.controls,
                self.container_1,
            ],
        )

        if not vertical_layout:
            self.children_3 = [
                self.player,
                self.container_2,
            ]
        else:  # vertical_layout
            self.children_3 = [
                self.container_2,
            ]

        self.container_3 = Box(
            name="container-3",
            h_expand=True,
            v_expand=True,
            orientation="h",
            spacing=8,
            children=self.children_3,
        )

        self.add(self.container_3)
        print(f"[{time.strftime('%H:%M:%S')}] Widgets layout complete")

    def on_applet_stack_changed(self, stack, param):
        visible_child = stack.get_visible_child()
        child_name = "unknown"
        if visible_child == self.notification_history:
            child_name = "notification_history"
        elif visible_child == self.network_connections:
            child_name = "network_connections"
        elif visible_child == self.bluetooth:
            child_name = "bluetooth"
        print(f"[{time.strftime('%H:%M:%S')}] applet_stack changed to {child_name}")

    def show_bt(self):
        print(f"[{time.strftime('%H:%M:%S')}] Showing BluetoothConnections")
        self.applet_stack.set_visible_child(self.bluetooth)

    def show_notif(self):
        print(f"[{time.strftime('%H:%M:%S')}] Showing NotificationHistory")
        self.applet_stack.set_visible_child(self.notification_history)

    def show_network_applet(self):
        print(f"[{time.strftime('%H:%M:%S')}] Showing NetworkConnections via notch")
        self.notch.open_notch("network_applet")
