import json
import locale
import os
import uuid
from datetime import datetime, timedelta
import time

from fabric.notifications.service import Notification, NotificationAction, Notifications
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.centerbox import CenterBox
from fabric.widgets.image import Image
from fabric.widgets.label import Label
from fabric.widgets.revealer import Revealer
from fabric.widgets.scrolledwindow import ScrolledWindow
from gi.repository import GdkPixbuf, GLib, Gtk
from loguru import logger

import config.data as data
import modules.icons as icons
from widgets.rounded_image import CustomImage
from widgets.wayland import WaylandWindow as Window

# Use a persistent directory in the user's home directory
PERSISTENT_DIR = os.path.expanduser(f"~/.config/{data.APP_NAME}/notifications")
CONFIG_FILE = os.path.join(PERSISTENT_DIR, "config.json")


# Data module for configuration management
def load_config():
    default_config = {
        "limited_apps_history": [],
        "history_ignored_apps": [""],
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                config = json.load(f)
                for key, value in default_config.items():
                    if key not in config:
                        config[key] = value
                logger.debug(
                    f"[{time.strftime('%H:%M:%S')}] Loaded config from {CONFIG_FILE}"
                )
                return config
        except Exception as e:
            logger.error(
                f"[{time.strftime('%H:%M:%S')}] Error loading config file: {e}"
            )
            return default_config
    return default_config


def save_config(config):
    try:
        os.makedirs(PERSISTENT_DIR, exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Saved config to {CONFIG_FILE}")
    except Exception as e:
        logger.error(f"[{time.strftime('%H:%M:%S')}] Error saving config file: {e}")


def get_limited_apps_history():
    config = load_config()
    return config.get("limited_apps_history", ["Spotify"])


def get_history_ignored_apps():
    config = load_config()
    return config.get("history_ignored_apps", ["Hyprshot"])


def cache_notification_pixbuf(notification_box):
    """
    Saves a scaled pixbuf (48x48) in the cache directory and returns the cache file path.
    """
    notification = notification_box.notification
    if notification.image_pixbuf:
        os.makedirs(PERSISTENT_DIR, exist_ok=True)
        cache_file = os.path.join(
            PERSISTENT_DIR, f"notification_{notification_box.uuid}.png"
        )
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Caching image for notification {notification.id} to: {cache_file}"
        )
        try:
            scaled = notification.image_pixbuf.scale_simple(
                48, 48, GdkPixbuf.InterpType.BILINEAR
            )
            scaled.savev(cache_file, "png", [], [])
            logger.info(
                f"[{time.strftime('%H:%M:%S')}] Successfully cached image for notification {notification.id}"
            )
            return cache_file
        except Exception as e:
            logger.error(
                f"[{time.strftime('%H:%M:%S')}] Error caching image for notification {notification.id}: {e}"
            )
            return None
    else:
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Notification {notification.id} has no image_pixbuf to cache"
        )
        return None


def load_scaled_pixbuf(notification_box, width, height):
    """
    Loads and scales a pixbuf for a notification_box, prioritizing cached images.
    """
    notification = notification_box.notification
    if not hasattr(notification_box, "notification") or notification is None:
        logger.error(
            f"[{time.strftime('%H:%M:%S')}] load_scaled_pixbuf: notification_box.notification is None or not set"
        )
        return None

    pixbuf = None
    if (
        hasattr(notification_box, "cached_image_path")
        and notification_box.cached_image_path
        and os.path.exists(notification_box.cached_image_path)
    ):
        try:
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Loading cached image from: {notification_box.cached_image_path} for notification {notification.id}"
            )
            pixbuf = GdkPixbuf.Pixbuf.new_from_file(notification_box.cached_image_path)
            if pixbuf:
                pixbuf = pixbuf.scale_simple(
                    width, height, GdkPixbuf.InterpType.BILINEAR
                )
                logger.info(
                    f"[{time.strftime('%H:%M:%S')}] Successfully loaded cached image for notification {notification.id}"
                )
            return pixbuf
        except Exception as e:
            logger.error(
                f"[{time.strftime('%H:%M:%S')}] Error loading cached image for notification {notification.id}: {e}"
            )
            logger.warning(
                f"[{time.strftime('%H:%M:%S')}] Falling back to notification.image_pixbuf for notification {notification.id}"
            )

    if notification.image_pixbuf:
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Loading image directly from notification.image_pixbuf for notification {notification.id}"
        )
        pixbuf = notification.image_pixbuf.scale_simple(
            width, height, GdkPixbuf.InterpType.BILINEAR
        )
        return pixbuf

    logger.debug(
        f"[{time.strftime('%H:%M:%S')}] No image_pixbuf or cached image, trying app icon for notification {notification.id}"
    )
    return get_app_icon_pixbuf(notification.app_icon, width, height)


def get_app_icon_pixbuf(icon_path, width, height):
    """
    Loads and scales a pixbuf from an app icon path.
    """
    if not icon_path:
        return None
    if icon_path.startswith("file://"):
        icon_path = icon_path[7:]
    if not os.path.exists(icon_path):
        logger.warning(
            f"[{time.strftime('%H:%M:%S')}] Icon path does not exist: {icon_path}"
        )
        return None
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(icon_path)
        return pixbuf.scale_simple(width, height, GdkPixbuf.InterpType.BILINEAR)
    except Exception as e:
        logger.error(f"[{time.strftime('%H:%M:%S')}] Failed to load or scale icon: {e}")
        return None


class ActionButton(Button):
    def __init__(
        self, action: NotificationAction, index: int, total: int, notification_box
    ):
        super().__init__(
            name="action-button",
            h_expand=True,
            on_clicked=self.on_clicked,
            child=Label(
                name="button-label",
                h_expand=True,
                h_align="fill",
                ellipsization="end",
                max_chars_width=1,
                label=action.label,
            ),
        )
        self.action = action
        self.notification_box = notification_box
        style_class = (
            "start-action"
            if index == 0
            else "end-action"
            if index == total - 1
            else "middle-action"
        )
        self.add_style_class(style_class)
        self.connect(
            "enter-notify-event", lambda *_: notification_box.hover_button(self)
        )
        self.connect(
            "leave-notify-event", lambda *_: notification_box.unhover_button(self)
        )

    def on_clicked(self, *_):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Action button clicked: {self.action.label}"
        )
        self.action.invoke()
        self.action.parent.close("dismissed-by-user")


class NotificationBox(Box):
    def __init__(self, notification: Notification, timeout_ms=5000, **kwargs):
        super().__init__(
            name="notification-box",
            orientation="v",
            h_align="fill",
            h_expand=True,
            children=[],
        )
        self.notification = notification
        self.uuid = str(uuid.uuid4())
        self.timeout_ms = (
            notification.timeout if notification.timeout != -1 else timeout_ms
        )
        self._timeout_id = None
        self._container = None
        self.cached_image_path = None
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Creating NotificationBox {self.uuid} for notification {notification.id}"
        )

        if self.timeout_ms > 0:
            self.start_timeout()

        if notification.image_pixbuf:
            self.cached_image_path = cache_notification_pixbuf(self)
            if not self.cached_image_path:
                logger.warning(
                    f"[{time.strftime('%H:%M:%S')}] Failed to cache image for notification {notification.id}"
                )

        content = self.create_content()
        action_buttons = self.create_action_buttons()
        self.add(content)
        if action_buttons:
            self.add(action_buttons)

        self.connect("enter-notify-event", self.on_hover_enter)
        self.connect("leave-notify-event", self.on_hover_leave)
        self._destroyed = False
        self._is_history = False

    def set_is_history(self, is_history):
        self._is_history = is_history
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] NotificationBox {self.uuid} set is_history: {is_history}"
        )

    def set_container(self, container):
        self._container = container

    def get_container(self):
        return self._container

    def create_header(self):
        notification = self.notification
        self.app_icon_image = (
            Image(
                name="notification-icon",
                image_file=notification.app_icon[7:],
                size=24,
            )
            if "file://" in notification.app_icon
            else Image(
                name="notification-icon",
                icon_name="dialog-information-symbolic" or notification.app_icon,
                icon_size=24,
            )
        )
        self.app_name_label_header = Label(
            notification.app_name, name="notification-app-name", h_align="start"
        )
        self.header_close_button = self.create_close_button()

        return CenterBox(
            name="notification-title",
            start_children=[
                Box(
                    spacing=4,
                    children=[
                        self.app_icon_image,
                        self.app_name_label_header,
                    ],
                )
            ],
            end_children=[self.header_close_button],
        )

    def create_content(self):
        notification = self.notification
        pixbuf = load_scaled_pixbuf(self, 48, 48)
        self.notification_image_box = Box(
            name="notification-image",
            orientation="v",
            children=[CustomImage(pixbuf=pixbuf), Box(v_expand=True)],
        )
        self.notification_summary_label = Label(
            name="notification-summary",
            markup=notification.summary,
            h_align="start",
            max_chars_width=16,
            ellipsization="end",
        )
        self.notification_app_name_label_content = Label(
            name="notification-app-name",
            markup=notification.app_name,
            h_align="start",
            max_chars_width=16,
            ellipsization="end",
        )
        self.notification_body_label = (
            Label(
                markup=notification.body,
                h_align="start",
                max_chars_width=34,
                ellipsization="end",
            )
            if notification.body
            else Box()
        )
        self.notification_body_label.set_single_line_mode(
            True
        ) if notification.body else None
        self.notification_text_box = Box(
            name="notification-text",
            orientation="v",
            v_align="center",
            h_expand=True,
            h_align="start",
            children=[
                Box(
                    name="notification-summary-box",
                    orientation="h",
                    children=[
                        self.notification_summary_label,
                        Box(
                            name="notif-sep",
                            h_expand=False,
                            v_expand=False,
                            h_align="center",
                            v_align="center",
                        ),
                        self.notification_app_name_label_content,
                    ],
                ),
                self.notification_body_label,
            ],
        )
        self.content_close_button = self.create_close_button()
        self.content_close_button_box = Box(
            orientation="v",
            children=[
                self.content_close_button,
            ],
        )

        return Box(
            name="notification-content",
            spacing=8,
            children=[
                self.notification_image_box,
                self.notification_text_box,
                self.content_close_button_box,
            ],
        )

    def create_action_buttons(self):
        notification = self.notification
        if not notification.actions:
            return None

        grid = Gtk.Grid()
        grid.set_column_homogeneous(True)
        grid.set_column_spacing(4)
        for i, action in enumerate(notification.actions):
            action_button = ActionButton(action, i, len(notification.actions), self)
            grid.attach(action_button, i, 0, 1, 1)
        return grid

    def create_close_button(self):
        self.close_button = Button(
            name="notif-close-button",
            child=Label(name="notif-close-label", markup=icons.cancel),
            on_clicked=lambda *_: self.notification.close("dismissed-by-user"),
        )
        self.close_button.connect(
            "enter-notify-event", lambda *_: self.hover_button(self.close_button)
        )
        self.close_button.connect(
            "leave-notify-event", lambda *_: self.unhover_button(self.close_button)
        )
        return self.close_button

    def on_hover_enter(self, *args):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] NotificationBox {self.uuid} hover enter"
        )
        if self._container:
            self._container.pause_and_reset_all_timeouts()

    def on_hover_leave(self, *args):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] NotificationBox {self.uuid} hover leave"
        )
        if self._container:
            self._container.resume_all_timeouts()

    def start_timeout(self):
        self.stop_timeout()
        if self.timeout_ms > 0:
            self._timeout_id = GLib.timeout_add(
                self.timeout_ms, self.close_notification
            )
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Started timeout for NotificationBox {self.uuid} ({self.timeout_ms}ms)"
            )

    def stop_timeout(self):
        if self._timeout_id is not None:
            GLib.source_remove(self._timeout_id)
            self._timeout_id = None
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Stopped timeout for NotificationBox {self.uuid}"
            )

    def close_notification(self):
        if not self._destroyed:
            try:
                logger.debug(
                    f"[{time.strftime('%H:%M:%S')}] Closing NotificationBox {self.uuid} (timeout expired)"
                )
                self.notification.close("expired")
                self.stop_timeout()
            except Exception as e:
                logger.error(
                    f"[{time.strftime('%H:%M:%S')}] Error closing NotificationBox {self.uuid}: {e}"
                )
        return False

    def destroy(self, from_history_delete=False):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Destroying NotificationBox {self.uuid}, from_history_delete: {from_history_delete}, is_history: {self._is_history}"
        )
        if (
            hasattr(self, "cached_image_path")
            and self.cached_image_path
            and os.path.exists(self.cached_image_path)
            and (not self._is_history or from_history_delete)
        ):
            try:
                os.remove(self.cached_image_path)
                logger.info(
                    f"[{time.strftime('%H:%M:%S')}] Deleted cached image: {self.cached_image_path}"
                )
            except Exception as e:
                logger.error(
                    f"[{time.strftime('%H:%M:%S')}] Error deleting cached image {self.cached_image_path}: {e}"
                )
        self._destroyed = True
        self.stop_timeout()
        super().destroy()

    def hover_button(self, button):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Hovering button in NotificationBox {self.uuid}"
        )
        if self._container:
            self._container.pause_and_reset_all_timeouts()

    def unhover_button(self, button):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Unhovering button in NotificationBox {self.uuid}"
        )
        if self._container:
            self._container.resume_all_timeouts()


class HistoricalNotification(object):
    def __init__(
        self, id, app_icon, summary, body, app_name, timestamp, cached_image_path=None
    ):
        self.id = id
        self.app_icon = app_icon
        self.summary = summary
        self.body = body
        self.app_name = app_name
        self.timestamp = timestamp
        self.cached_image_path = cached_image_path
        self.image_pixbuf = None
        self.actions = []
        self.cached_scaled_pixbuf = None


class NotificationHistory(Box):
    def __init__(self, **kwargs):
        super().__init__(name="notification-history", orientation="v", **kwargs)
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Initializing NotificationHistory")

        # Load config and set DND state
        config = load_config()
        self.do_not_disturb_enabled = config.get("do_not_disturb_enabled", False)

        self.containers = []
        self.header_label = Label(
            name="nhh",
            label="Notifications",
            h_align="start",
            h_expand=True,
        )
        self.header_switch = Gtk.Switch(name="dnd-switch")
        self.header_switch.set_vexpand(False)
        self.header_switch.set_valign(Gtk.Align.CENTER)
        self.header_switch.set_active(self.do_not_disturb_enabled)
        self.header_clean = Button(
            name="nhh-button",
            child=Label(name="nhh-button-label", markup=icons.trash),
            on_clicked=self.clear_history,
        )
        self.header_switch.connect("notify::active", self.on_do_not_disturb_changed)
        self.dnd_label = Label(name="dnd-label", markup=icons.notifications_off)

        self.history_header = CenterBox(
            name="notification-history-header",
            spacing=8,
            start_children=[self.header_switch, self.dnd_label],
            center_children=[self.header_label],
            end_children=[self.header_clean],
        )
        self.notifications_list = Box(
            name="notifications-list",
            orientation="v",
            spacing=4,
            h_expand=True,
            v_expand=True,
            h_align="fill",
            v_align="fill",
        )
        self.no_notifications_label = Label(
            name="no-notif",
            markup=icons.notifications_clear,
            v_align="fill",
            h_align="fill",
            v_expand=True,
            h_expand=True,
            justification="center",
        )
        self.no_notifications_box = Box(
            name="no-notifications-box",
            v_align="fill",
            h_align="fill",
            v_expand=True,
            h_expand=True,
            children=[self.no_notifications_label],
        )
        self.scrolled_window = ScrolledWindow(
            name="notification-history-scrolled-window",
            orientation="v",
            h_expand=True,
            v_expand=True,
            h_align="fill",
            v_align="fill",
            propagate_width=False,
            propagate_height=False,
        )
        self.scrolled_window_viewport_box = Box(
            orientation="v",
            children=[self.notifications_list, self.no_notifications_box],
        )
        self.scrolled_window.add_with_viewport(self.scrolled_window_viewport_box)
        self.persistent_notifications = []
        self.add(self.history_header)
        self.add(self.scrolled_window)
        self._load_persistent_history()
        self._cleanup_orphan_cached_images()
        self.schedule_midnight_update()

    def on_do_not_disturb_changed(self, switch, pspec):
        self.do_not_disturb_enabled = switch.get_active()
        logger.info(
            f"[{time.strftime('%H:%M:%S')}] Do Not Disturb mode {'enabled' if self.do_not_disturb_enabled else 'disabled'}"
        )
        config = load_config()
        config["do_not_disturb_enabled"] = self.do_not_disturb_enabled
        save_config(config)

    def get_ordinal(self, n):
        if 11 <= (n % 100) <= 13:
            return "th"
        else:
            return {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")

    def get_date_header(self, dt):
        now = datetime.now()
        today = now.date()
        date = dt.date()
        if date == today:
            return "Today"
        elif date == today - timedelta(days=1):
            return "Yesterday"
        else:
            original_locale = locale.getlocale(locale.LC_TIME)
            try:
                locale.setlocale(locale.LC_TIME, ("en_US", "UTF-8"))
            except locale.Error:
                locale.setlocale(locale.LC_TIME, "C")
            try:
                day = dt.day
                ordinal = self.get_ordinal(day)
                month = dt.strftime("%B")
                if dt.year == now.year:
                    result = f"{month} {day}{ordinal}"
                else:
                    result = f"{month} {day}{ordinal}, {dt.year}"
            finally:
                locale.setlocale(locale.LC_TIME, original_locale)
            return result

    def schedule_midnight_update(self):
        now = datetime.now()
        next_midnight = datetime.combine(
            now.date() + timedelta(days=1), datetime.min.time()
        )
        delta_seconds = (next_midnight - now).total_seconds()
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Scheduled midnight update in {int(delta_seconds)} seconds"
        )
        GLib.timeout_add_seconds(int(delta_seconds), self.on_midnight)

    def on_midnight(self):
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Midnight update triggered")
        self.rebuild_with_separators()
        self.schedule_midnight_update()
        return GLib.SOURCE_REMOVE

    def create_date_separator(self, date_header):
        return Box(
            name="notif-date-sep",
            children=[
                Label(
                    name="notif-date-sep-label",
                    label=date_header,
                    h_align="center",
                    h_expand=True,
                )
            ],
        )

    def rebuild_with_separators(self):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Rebuilding notification history with separators"
        )
        GLib.idle_add(self._do_rebuild_with_separators)

    def _do_rebuild_with_separators(self):
        children = list(self.notifications_list.get_children())
        for child in children:
            self.notifications_list.remove(child)

        current_date_header = None
        last_date_header = None
        for container in sorted(
            self.containers, key=lambda x: x.arrival_time, reverse=True
        ):
            arrival_time = container.arrival_time
            date_header = self.get_date_header(arrival_time)
            if date_header != current_date_header:
                sep = self.create_date_separator(date_header)
                self.notifications_list.add(sep)
                current_date_header = date_header
                last_date_header = date_header
            self.notifications_list.add(container)

        if not self.containers and last_date_header:
            for child in list(self.notifications_list.get_children()):
                if child.get_name() == "notif-date-sep":
                    self.notifications_list.remove(child)

        self.notifications_list.show_all()
        self.update_no_notifications_label_visibility()

    def clear_history(self, *args):
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Clearing notification history")
        for child in self.notifications_list.get_children()[:]:
            container = child
            notif_box = (
                container.notification_box
                if hasattr(container, "notification_box")
                else None
            )
            if notif_box:
                notif_box.destroy(from_history_delete=True)
            self.notifications_list.remove(child)
            child.destroy()

        self.persistent_notifications = []
        self.containers = []
        self.rebuild_with_separators()

    def _load_persistent_history(self):
        if not os.path.exists(PERSISTENT_DIR):
            os.makedirs(PERSISTENT_DIR, exist_ok=True)
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Created persistent directory: {PERSISTENT_DIR}"
            )
        GLib.idle_add(self.update_no_notifications_label_visibility)

    def delete_historical_notification(self, note_id, container):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Deleting historical notification {note_id}"
        )
        if hasattr(container, "notification_box"):
            notif_box = container.notification_box
            notif_box.destroy(from_history_delete=True)

        target_note_id_str = str(note_id)
        new_persistent_notifications = []
        removed_from_list = False
        for note_in_list in self.persistent_notifications:
            current_note_id_str = str(note_in_list.get("id"))
            if current_note_id_str == target_note_id_str:
                removed_from_list = True
                continue
            new_persistent_notifications.append(note_in_list)

        if removed_from_list:
            self.persistent_notifications = new_persistent_notifications
            logger.info(
                f"[{time.strftime('%H:%M:%S')}] Notification {target_note_id_str} removed from persistent_notifications"
            )
        else:
            logger.warning(
                f"[{time.strftime('%H:%M:%S')}] Notification {target_note_id_str} not found in persistent_notifications"
            )

        container.destroy()
        self.containers = [c for c in self.containers if c != container]
        self.rebuild_with_separators()

    def _add_historical_notification(self, note):
        hist_notif = HistoricalNotification(
            id=note.get("id"),
            app_icon=note.get("app_icon"),
            summary=note.get("summary"),
            body=note.get("body"),
            app_name=note.get("app_name"),
            timestamp=note.get("timestamp"),
            cached_image_path=note.get("cached_image_path"),
        )
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Adding historical notification {hist_notif.id}"
        )

        hist_box = NotificationBox(hist_notif, timeout_ms=0)
        hist_box.uuid = hist_notif.id
        hist_box.cached_image_path = hist_notif.cached_image_path
        hist_box.set_is_history(True)
        for child in hist_box.get_children():
            if child.get_name() == "notification-action-buttons":
                hist_box.remove(child)
        container = Box(
            name="notification-container",
            orientation="v",
            h_align="fill",
            h_expand=True,
        )
        container.notification_box = hist_box
        try:
            arrival = datetime.fromisoformat(hist_notif.timestamp)
        except Exception:
            arrival = datetime.now()
        container.arrival_time = arrival

        def compute_time_label(arrival_time):
            return arrival_time.strftime("%H:%M")

        self.hist_time_label = Label(
            name="notification-timestamp",
            markup=compute_time_label(container.arrival_time),
            h_align="start",
            ellipsization="end",
        )
        self.hist_notif_image_box = Box(
            name="notification-image",
            orientation="v",
            children=[
                CustomImage(pixbuf=load_scaled_pixbuf(hist_box, 48, 48)),
                Box(v_expand=True),
            ],
        )
        self.hist_notif_summary_label = Label(
            name="notification-summary",
            markup=hist_notif.summary,
            h_align="start",
            ellipsization="end",
        )

        self.hist_notif_app_name_label = Label(
            name="notification-app-name",
            markup=f"{hist_notif.app_name}",
            h_align="start",
            ellipsization="end",
        )

        self.hist_notif_body_label = (
            Label(
                name="notification-body",
                markup=hist_notif.body,
                h_align="start",
                ellipsization="end",
                line_wrap="word-char",
            )
            if hist_notif.body
            else Box()
        )
        self.hist_notif_body_label.set_single_line_mode(
            True
        ) if hist_notif.body else None

        self.hist_notif_summary_box = Box(
            name="notification-summary-box",
            orientation="h",
            children=[
                self.hist_notif_summary_label,
                Box(
                    name="notif-sep",
                    h_expand=False,
                    v_expand=False,
                    h_align="center",
                    v_align="center",
                ),
                self.hist_notif_app_name_label,
                Box(
                    name="notif-sep",
                    h_expand=False,
                    v_expand=False,
                    h_align="center",
                    v_align="center",
                ),
                self.hist_time_label,
            ],
        )
        self.hist_notif_text_box = Box(
            name="notification-text",
            orientation="v",
            v_align="center",
            h_expand=True,
            children=[
                self.hist_notif_summary_box,
                self.hist_notif_body_label,
            ],
        )
        self.hist_notif_close_button = Button(
            name="notif-close-button",
            child=Label(name="notif-close-label", markup=icons.cancel),
            on_clicked=lambda *_: self.delete_historical_notification(
                hist_notif.id, container
            ),
        )
        self.hist_notif_close_button_box = Box(
            orientation="v",
            children=[
                self.hist_notif_close_button,
                Box(v_expand=True),
            ],
        )
        content_box = Box(
            name="notification-box-hist",
            spacing=8,
            children=[
                self.hist_notif_image_box,
                self.hist_notif_text_box,
                self.hist_notif_close_button_box,
            ],
        )
        container.add(content_box)
        self.containers.insert(0, container)
        self.rebuild_with_separators()
        self.update_no_notifications_label_visibility()

    def add_notification(self, notification_box):
        app_name = notification_box.notification.app_name
        if app_name in get_history_ignored_apps():
            logger.info(
                f"[{time.strftime('%H:%M:%S')}] Ignoring notification from {app_name} (in ignored list)"
            )
            notification_box.destroy(from_history_delete=True)
            return

        if app_name in get_limited_apps_history():
            self.clear_history_for_app(app_name)

        if len(self.containers) >= 20:  # Reduced from 50 to 20
            oldest_container = self.containers.pop()
            if (
                hasattr(oldest_container, "notification_box")
                and hasattr(oldest_container.notification_box, "cached_image_path")
                and oldest_container.notification_box.cached_image_path
                and os.path.exists(oldest_container.notification_box.cached_image_path)
            ):
                try:
                    os.remove(oldest_container.notification_box.cached_image_path)
                    logger.info(
                        f"[{time.strftime('%H:%M:%S')}] Deleted cached image of oldest notification: {oldest_container.notification_box.cached_image_path}"
                    )
                except Exception as e:
                    logger.error(
                        f"[{time.strftime('%H:%M:%S')}] Error deleting cached image of oldest notification: {e}"
                    )
            oldest_container.destroy()

        def on_container_destroy(container):
            if (
                hasattr(container, "_timestamp_timer_id")
                and container._timestamp_timer_id
            ):
                GLib.source_remove(container._timestamp_timer_id)

            container.destroy()
            self.containers.remove(container)
            self.rebuild_with_separators()
            self.update_no_notifications_label_visibility()

        container = Box(
            name="notification-container",
            orientation="v",
            h_align="fill",
            h_expand=True,
        )
        container.arrival_time = datetime.now()

        def compute_time_label(arrival_time):
            return arrival_time.strftime("%H:%M")

        self.current_time_label = Label(
            name="notification-timestamp",
            markup=compute_time_label(container.arrival_time),
        )
        self.current_notif_image_box = Box(
            name="notification-image",
            orientation="v",
            children=[
                CustomImage(pixbuf=load_scaled_pixbuf(notification_box, 48, 48)),
                Box(v_expand=True, v_align="fill"),
            ],
        )
        self.current_notif_summary_label = Label(
            name="notification-summary",
            markup=notification_box.notification.summary,
            h_align="start",
            ellipsization="end",
        )
        self.current_notif_app_name_label = Label(
            name="notification-app-name",
            markup=f"{notification_box.notification.app_name}",
            h_align="start",
            ellipsization="end",
        )
        self.current_notif_body_label = (
            Label(
                name="notification-body",
                markup=notification_box.notification.body,
                h_align="start",
                ellipsization="end",
                line_wrap="word-char",
            )
            if notification_box.notification.body
            else Box()
        )
        self.current_notif_body_label.set_single_line_mode(
            True
        ) if notification_box.notification.body else None
        self.current_notif_summary_box = Box(
            name="notification-summary-box",
            orientation="h",
            children=[
                self.current_notif_summary_label,
                Box(
                    name="notif-sep",
                    h_expand=False,
                    v_expand=False,
                    h_align="center",
                    v_align="center",
                ),
                self.current_notif_app_name_label,
                Box(
                    name="notif-sep",
                    h_expand=False,
                    v_expand=False,
                    h_align="center",
                    v_align="center",
                ),
                self.current_time_label,
            ],
        )
        self.current_notif_text_box = Box(
            name="notification-text",
            orientation="v",
            v_align="center",
            h_expand=True,
            children=[
                self.current_notif_summary_box,
                self.current_notif_body_label,
            ],
        )
        self.current_notif_close_button = Button(
            name="notif-close-button",
            child=Label(name="notif-close-label", markup=icons.cancel),
            on_clicked=lambda *_: on_container_destroy(container),
        )
        self.current_notif_close_button_box = Box(
            name="notif-close-button-box",
            orientation="v",
            children=[
                self.current_notif_close_button,
                Box(v_expand=True),
            ],
        )
        content_box = Box(
            name="notification-content",
            spacing=8,
            children=[
                self.current_notif_image_box,
                self.current_notif_text_box,
                self.current_notif_close_button_box,
            ],
        )
        container.notification_box = notification_box
        hist_box = Box(
            name="notification-box-hist",
            orientation="v",
            h_align="fill",
            h_expand=True,
        )
        hist_box.add(content_box)
        content_box.get_children()[2].get_children()[0].connect(
            "clicked", lambda *_: on_container_destroy(container)
        )
        container.add(hist_box)
        self.containers.insert(0, container)
        self.rebuild_with_separators()
        self._append_persistent_notification(notification_box, container.arrival_time)
        self.update_no_notifications_label_visibility()

    def _append_persistent_notification(self, notification_box, arrival_time):
        note = {
            "id": notification_box.uuid,
            "app_icon": notification_box.notification.app_icon,
            "summary": notification_box.notification.summary,
            "body": notification_box.notification.body,
            "app_name": notification_box.notification.app_name,
            "timestamp": arrival_time.isoformat(),
            "cached_image_path": notification_box.cached_image_path,
        }
        self.persistent_notifications.insert(0, note)
        self.persistent_notifications = self.persistent_notifications[
            :20
        ]  # Reduced from 50
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Appended persistent notification {notification_box.uuid}"
        )

    def _cleanup_orphan_cached_images(self):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Starting orphan cached image cleanup"
        )
        if not os.path.exists(PERSISTENT_DIR):
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Cache directory does not exist"
            )
            return

        cached_files = [
            f
            for f in os.listdir(PERSISTENT_DIR)
            if f.startswith("notification_") and f.endswith(".png")
        ]
        if not cached_files:
            logger.debug(f"[{time.strftime('%H:%M:%S')}] No cached image files found")
            return

        history_uuids = {
            note.get("id") for note in self.persistent_notifications if note.get("id")
        }
        deleted_count = 0
        for cached_file in cached_files:
            try:
                uuid_from_filename = cached_file[len("notification_") : -len(".png")]
                if uuid_from_filename not in history_uuids:
                    cache_file_path = os.path.join(PERSISTENT_DIR, cached_file)
                    os.remove(cache_file_path)
                    logger.info(
                        f"[{time.strftime('%H:%M:%S')}] Deleted orphan cached image: {cache_file_path}"
                    )
                    deleted_count += 1
                else:
                    logger.debug(
                        f"[{time.strftime('%H:%M:%S')}] Cached image {cached_file} found in history"
                    )
            except Exception as e:
                logger.error(
                    f"[{time.strftime('%H:%M:%S')}] Error processing cached file {cached_file}: {e}"
                )

        logger.info(
            f"[{time.strftime('%H:%M:%S')}] Orphan cached image cleanup finished. Deleted {deleted_count} images"
        )

    def update_no_notifications_label_visibility(self):
        has_notifications = bool(self.containers)
        self.no_notifications_box.set_visible(not has_notifications)
        self.notifications_list.set_visible(has_notifications)
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Updated no_notifications_label visibility: {'visible' if not has_notifications else 'hidden'}"
        )

    def clear_history_for_app(self, app_name):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Clearing history for app: {app_name}"
        )
        containers_to_remove = []
        persistent_notes_to_remove_ids = set()
        for container in list(self.containers):
            if (
                hasattr(container, "notification_box")
                and container.notification_box.notification.app_name == app_name
            ):
                containers_to_remove.append(container)
                persistent_notes_to_remove_ids.add(container.notification_box.uuid)

        for container in containers_to_remove:
            if (
                hasattr(container, "notification_box")
                and hasattr(container.notification_box, "cached_image_path")
                and container.notification_box.cached_image_path
                and os.path.exists(container.notification_box.cached_image_path)
            ):
                try:
                    os.remove(container.notification_box.cached_image_path)
                    logger.info(
                        f"[{time.strftime('%H:%M:%S')}] Deleted cached image of replaced history notification: {container.notification_box.cached_image_path}"
                    )
                except Exception as e:
                    logger.error(
                        f"[{time.strftime('%H:%M:%S')}] Error deleting cached image of replaced history notification: {e}"
                    )
            self.containers.remove(container)
            self.notifications_list.remove(container)
            container.notification_box.destroy(from_history_delete=True)
            container.destroy()

        self.persistent_notifications = [
            note
            for note in self.persistent_notifications
            if note.get("id") not in persistent_notes_to_remove_ids
        ]
        self.rebuild_with_separators()
        self.update_no_notifications_label_visibility()


class NotificationContainer(Box):
    def __init__(
        self,
        notification_history_instance: NotificationHistory,
        revealer_transition_type: str = "slide-down",
    ):
        super().__init__(name="notification-container-main", orientation="v", spacing=4)
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Initializing NotificationContainer"
        )
        self.notification_history = notification_history_instance

        self._server = Notifications()
        self._server.connect("notification-added", self.on_new_notification)
        self._pending_removal = False
        self._is_destroying = False

        self.stack = Gtk.Stack(
            name="notification-stack",
            transition_type="none",  # Disable transitions to reduce lag
            transition_duration=0,
            visible=True,
        )
        self.navigation = Box(
            name="notification-navigation", spacing=4, h_align="center"
        )
        self.stack_box = Box(
            name="notification-stack-box",
            h_align="center",
            h_expand=False,
            children=[self.stack],
        )
        self.prev_button = Button(
            name="nav-button",
            child=Label(name="nav-button-label", markup=icons.chevron_left),
            on_clicked=self.show_previous,
        )
        self.close_all_button = Button(
            name="nav-button",
            child=Label(name="nav-button-label", markup=icons.cancel),
            on_clicked=self.close_all_notifications,
        )
        self.close_all_button_label = self.close_all_button.get_child()
        self.close_all_button_label.add_style_class("close")
        self.next_button = Button(
            name="nav-button",
            child=Label(name="nav-button-label", markup=icons.chevron_right),
            on_clicked=self.show_next,
        )
        for button in [self.prev_button, self.close_all_button, self.next_button]:
            button.connect(
                "enter-notify-event", lambda *_: self.pause_and_reset_all_timeouts()
            )
            button.connect("leave-notify-event", lambda *_: self.resume_all_timeouts())
        self.navigation.add(self.prev_button)
        self.navigation.add(self.close_all_button)
        self.navigation.add(self.next_button)

        self.navigation_revealer = Revealer(
            transition_type="slide-down",
            transition_duration=200,
            child=self.navigation,
            reveal_child=False,
        )

        self.notification_box_container = Box(
            name="notification-box-internal-container",
            orientation="v",
            children=[self.stack_box, self.navigation_revealer],
        )

        self.main_revealer = Revealer(
            name="notification-main-revealer",
            transition_type=revealer_transition_type,
            transition_duration=250,
            child_revealed=False,
            child=self.notification_box_container,
        )

        self.add(self.main_revealer)

        self.notifications = []
        self.current_index = 0
        self.update_navigation_buttons()
        self._destroyed_notifications = set()

    def on_new_notification(self, fabric_notif, id):
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] New notification received: ID {id}"
        )
        notification_history_instance = self.notification_history
        notification = fabric_notif.get_notification_from_id(id)

        # Check if the notification has an expire-time set (from notify-send -e)
        skip_history = notification.timeout > 0  # True if expire-time is set

        if (
            notification_history_instance.do_not_disturb_enabled
            and notification.urgency != 2
        ):
            logger.info(
                f"[{time.strftime('%H:%M:%S')}] DND enabled, adding notification {notification.id} to history"
            )
            new_box = NotificationBox(notification)
            if notification.image_pixbuf:
                cache_notification_pixbuf(new_box)
            if not skip_history:
                notification_history_instance.add_notification(new_box)
            else:
                logger.debug(
                    f"[{time.strftime('%H:%M:%S')}] Skipping history for notification {notification.id} due to expire-time"
                )
            return

        new_box = NotificationBox(notification)
        new_box.set_container(self)
        notification.connect("closed", self.on_notification_closed)

        app_name = notification.app_name
        if app_name in get_limited_apps_history():
            notification_history_instance.clear_history_for_app(app_name)

            existing_notification_index = -1
            for index, existing_box in enumerate(self.notifications):
                if existing_box.notification.app_name == app_name:
                    existing_notification_index = index
                    break

            if existing_notification_index != -1:
                old_notification_box = self.notifications.pop(
                    existing_notification_index
                )
                self.stack.remove(old_notification_box)
                old_notification_box.destroy()

                self.stack.add_named(new_box, str(id))
                self.notifications.append(new_box)
                self.current_index = len(self.notifications) - 1
                self.stack.set_visible_child(new_box)
            else:
                while len(self.notifications) >= 5:
                    oldest_notification = self.notifications[0]
                    if not skip_history:
                        notification_history_instance.add_notification(
                            oldest_notification
                        )
                    else:
                        logger.debug(
                            f"[{time.strftime('%H:%M:%S')}] Skipping history for oldest notification {oldest_notification.notification.id} due to expire-time"
                        )
                    self.stack.remove(oldest_notification)
                    self.notifications.pop(0)
                    if self.current_index > 0:
                        self.current_index -= 1
                self.stack.add_named(new_box, str(id))
                self.notifications.append(new_box)
                self.current_index = len(self.notifications) - 1
                self.stack.set_visible_child(new_box)
        else:
            while len(self.notifications) >= 5:
                oldest_notification = self.notifications[0]
                if not skip_history:
                    notification_history_instance.add_notification(oldest_notification)
                else:
                    logger.debug(
                        f"[{time.strftime('%H:%M:%S')}] Skipping history for oldest notification {oldest_notification.notification.id} due to expire-time"
                    )
                self.stack.remove(oldest_notification)
                self.notifications.pop(0)
                if self.current_index > 0:
                    self.current_index -= 1
            self.stack.add_named(new_box, str(id))
            self.notifications.append(new_box)
            self.current_index = len(self.notifications) - 1
            self.stack.set_visible_child(new_box)

        for notification_box in self.notifications:
            if notification_box == self.stack.get_visible_child():
                notification_box.start_timeout()
        self.main_revealer.show_all()
        self.main_revealer.set_reveal_child(True)
        self.update_navigation_buttons()

    def show_previous(self, *args):
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Showing previous notification")
        if self.current_index > 0:
            self.current_index -= 1
            self.stack.set_visible_child(self.notifications[self.current_index])
            self.update_navigation_buttons()

    def show_next(self, *args):
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Showing next notification")
        if self.current_index < len(self.notifications) - 1:
            self.current_index += 1
            self.stack.set_visible_child(self.notifications[self.current_index])
            self.update_navigation_buttons()

    def update_navigation_buttons(self):
        self.prev_button.set_sensitive(self.current_index > 0)
        self.next_button.set_sensitive(self.current_index < len(self.notifications) - 1)
        should_reveal = len(self.notifications) > 1
        self.navigation_revealer.set_reveal_child(should_reveal)
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Updated navigation buttons: prev={self.prev_button.get_sensitive()}, next={self.next_button.get_sensitive()}, reveal={should_reveal}"
        )

    def on_notification_closed(self, notification, reason):
        if self._is_destroying:
            return
        if notification.id in self._destroyed_notifications:
            return
        self._destroyed_notifications.add(notification.id)
        try:
            logger.info(
                f"[{time.strftime('%H:%M:%S')}] Notification {notification.id} closing with reason: {reason}"
            )
            notif_to_remove = None
            for i, notif_box in enumerate(self.notifications):
                if notif_box.notification.id == notification.id:
                    notif_to_remove = (i, notif_box)
                    break
            if not notif_to_remove:
                return
            i, notif_box = notif_to_remove
            reason_str = str(reason)

            notification_history_instance = self.notification_history
            skip_history = (
                notif_box.notification.timeout > 0
            )  # Check if expire-time is set

            if reason_str == "NotificationCloseReason.DISMISSED_BY_USER":
                logger.info(
                    f"[{time.strftime('%H:%M:%S')}] Cleaning up dismissed notification {notification.id}"
                )
                notif_box.destroy()
            elif (
                reason_str == "NotificationCloseReason.EXPIRED"
                or reason_str == "NotificationCloseReason.CLOSED"
                or reason_str == "NotificationCloseReason.UNDEFINED"
            ):
                if not skip_history:
                    logger.info(
                        f"[{time.strftime('%H:%M:%S')}] Adding notification {notification.id} to history (reason: {reason_str})"
                    )
                    notif_box.set_is_history(True)
                    notification_history_instance.add_notification(notif_box)
                    notif_box.stop_timeout()
                else:
                    logger.debug(
                        f"[{time.strftime('%H:%M:%S')}] Skipping history for notification {notification.id} due to expire-time"
                    )
                    notif_box.destroy()
            else:
                logger.warning(
                    f"[{time.strftime('%H:%M:%S')}] Unknown close reason: {reason_str} for notification {notification.id}"
                )
                notif_box.destroy()

            if len(self.notifications) == 1:
                self._is_destroying = True
                self.main_revealer.set_reveal_child(False)
                # Ensure the container is destroyed after the transition
                GLib.timeout_add(
                    self.main_revealer.get_transition_duration()
                    + 50,  # Add a small buffer
                    self._destroy_container,
                )
                return

            new_index = i
            if i == self.current_index:
                new_index = max(0, i - 1)
            elif i < self.current_index:
                new_index = self.current_index - 1

            if notif_box.get_parent() == self.stack:
                self.stack.remove(notif_box)
            self.notifications.pop(i)

            if new_index >= len(self.notifications) and len(self.notifications) > 0:
                new_index = len(self.notifications) - 1

            self.current_index = new_index

            if len(self.notifications) > 0:
                self.stack.set_visible_child(self.notifications[self.current_index])
            else:
                # Force hide the revealer if no notifications remain
                self.main_revealer.set_reveal_child(False)
                GLib.timeout_add(
                    self.main_revealer.get_transition_duration() + 50,
                    self._destroy_container,
                )

            self.update_navigation_buttons()
        except Exception as e:
            logger.error(
                f"[{time.strftime('%H:%M:%S')}] Error closing notification {notification.id}: {e}"
            )
            # Fallback to ensure UI is cleaned up
            self.main_revealer.set_reveal_child(False)
            GLib.timeout_add(
                self.main_revealer.get_transition_duration() + 50,
                self._destroy_container,
            )

    def _destroy_container(self):
        try:
            self.notifications.clear()
            self._destroyed_notifications.clear()
            for child in self.stack.get_children():
                self.stack.remove(child)
                child.destroy()
            self.current_index = 0
            self.main_revealer.set_reveal_child(False)  # Explicitly hide
            logger.debug(
                f"[{time.strftime('%H:%M:%S')}] Destroyed notification container"
            )
        except Exception as e:
            logger.error(
                f"[{time.strftime('%H:%M:%S')}] Error cleaning up container: {e}"
            )
        finally:
            self._is_destroying = False
            return False

    def pause_and_reset_all_timeouts(self):
        if self._is_destroying:
            return
        for notification in self.notifications[:]:
            try:
                if (
                    not notification._destroyed
                    and notification.get_parent()
                    and notification == self.stack.get_visible_child()
                ):
                    notification.stop_timeout()
                    logger.debug(
                        f"[{time.strftime('%H:%M:%S')}] Paused timeout for visible notification {notification.uuid}"
                    )
            except Exception as e:
                logger.error(
                    f"[{time.strftime('%H:%M:%S')}] Error pausing timeout for notification {notification.uuid}: {e}"
                )

    def resume_all_timeouts(self):
        if self._is_destroying:
            return
        for notification in self.notifications[:]:
            try:
                if (
                    not notification._destroyed
                    and notification.get_parent()
                    and notification == self.stack.get_visible_child()
                ):
                    notification.start_timeout()
                    logger.debug(
                        f"[{time.strftime('%H:%M:%S')}] Resumed timeout for visible notification {notification.uuid}"
                    )
            except Exception as e:
                logger.error(
                    f"[{time.strftime('%H:%M:%S')}] Error resuming timeout for notification {notification.uuid}: {e}"
                )

    def close_all_notifications(self, *args):
        logger.debug(f"[{time.strftime('%H:%M:%S')}] Closing all notifications")
        notifications_to_close = self.notifications.copy()
        for notification_box in notifications_to_close:
            notification_box.notification.close("dismissed-by-user")


class NotificationPopup(Window):
    def __init__(self, **kwargs):
        y_pos = data.NOTIF_POS.lower()
        x_pos = "right"

        if (
            data.BAR_POSITION in ["Top", "Bottom"]
            and data.PANEL_POSITION == "End"
            or x_pos == data.BAR_POSITION.lower()
        ):
            x_pos = "left"

        super().__init__(
            name="notification-popup",
            anchor=f"{x_pos} {y_pos}",
            layer="top",
            keyboard_mode="none",
            exclusivity="none",
            visible=True,
            all_visible=True,
        )
        logger.debug(
            f"[{time.strftime('%H:%M:%S')}] Initializing NotificationPopup at {x_pos} {y_pos}"
        )

        self.widgets = kwargs.get("widgets", None)
        self.notification_history = (
            self.widgets.notification_history if self.widgets else NotificationHistory()
        )
        self.notification_container = NotificationContainer(
            notification_history_instance=self.notification_history,
            revealer_transition_type="slide-down" if y_pos == "top" else "slide-up",
        )

        self.show_box = Box()
        self.show_box.set_size_request(1, 1)

        self.add(
            Box(
                name="notification-popup-box",
                orientation="v",
                children=[self.notification_container, self.show_box],
            )
        )
