import colorsys
import concurrent.futures
import hashlib
import os
import random
import shutil
import math
import statistics
from typing import Tuple
from concurrent.futures import ThreadPoolExecutor

from fabric.utils.helpers import exec_shell_command_async
from fabric.widgets.box import Box
from fabric.widgets.button import Button
from fabric.widgets.entry import Entry
from fabric.widgets.label import Label
from fabric.widgets.scrolledwindow import ScrolledWindow
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk
from PIL import Image

import config.data as data
import modules.icons as icons

class WallpaperSelector(Box):
    CACHE_DIR = f"{data.CACHE_DIR}/thumbs"

    def __init__(self, **kwargs):
        old_cache_dir = f"{data.CACHE_DIR}/wallpapers"
        if os.path.exists(old_cache_dir):
            shutil.rmtree(old_cache_dir)

        super().__init__(name="wallpapers", spacing=4, orientation="v", h_expand=False, v_expand=False, **kwargs)
        os.makedirs(self.CACHE_DIR, exist_ok=True)

        self.files = self._get_files_recursive(data.WALLPAPERS_DIR)
        self.thumbnails = []
        self.executor = ThreadPoolExecutor(max_workers=4)
        self.selected_index = -1
        self.search_timeout_id = None
        self.is_searching = False

        self.page_size = 9
        self.current_page = 0
        self.total_pages = math.ceil(len(self.files) / self.page_size) if self.files else 1

        self.search_page_size = self.page_size
        self.search_files = []
        self.search_current_page = 0
        self.search_total_pages = 0

        self.viewport = Gtk.IconView(name="wallpaper-icons")
        self.viewport.set_model(Gtk.ListStore(GdkPixbuf.Pixbuf, str, str))
        self.viewport.set_pixbuf_column(0)
        self.viewport.set_text_column(2)
        self.viewport.set_item_width(0)
        self.viewport.connect("item-activated", self.on_wallpaper_selected)

        self.scrolled_window = ScrolledWindow(
            name="scrolled-window",
            spacing=10,
            h_expand=True,
            v_expand=True,
            h_align="fill",
            v_align="fill",
            child=self.viewport,
            propagate_width=False,
            propagate_height=False,
        )

        self.search_entry = Entry(
            name="search-entry-walls",
            placeholder="Search Wallpapers...",
            h_expand=True,
            h_align="fill",
            notify_text=lambda entry, *_: self.arrange_viewport(entry.get_text()),
            on_key_press_event=self.on_search_entry_key_press,
        )
        self.search_entry.props.xalign = 0.5

        self.schemes = {
            "scheme-tonal-spot": "Tonal Spot",
            "scheme-content": "Content",
            "scheme-expressive": "Expressive",
            "scheme-fidelity": "Fidelity",
            "scheme-fruit-salad": "Fruit Salad",
            "scheme-monochrome": "Monochrome",
            "scheme-neutral": "Neutral",
            "scheme-rainbow": "Rainbow",
        }
        self.scheme_dropdown = Gtk.ComboBoxText()
        self.scheme_dropdown.set_name("scheme-dropdown")
        self.scheme_dropdown.set_tooltip_text("Select color scheme")
        for key, display_name in self.schemes.items():
            self.scheme_dropdown.append(key, display_name)
        self.scheme_dropdown.set_active_id("scheme-content")
        self.scheme_dropdown.connect("changed", self.on_scheme_changed)

        self.matugen_enabled = True
        try:
            with open(data.MATUGEN_STATE_FILE, 'r') as f:
                content = f.read().strip().lower()
                if content == "false":
                    self.matugen_enabled = False
                elif content == "true":
                    self.matugen_enabled = True
        except FileNotFoundError:
            pass
        except Exception as e:
            print(f"Error reading matugen state file: {e}")
        self.matugen_switcher = Gtk.Switch(name="matugen-switcher")
        self.matugen_switcher.set_tooltip_text("Toggle dynamic colors")
        self.matugen_switcher.set_vexpand(False)
        self.matugen_switcher.set_hexpand(False)
        self.matugen_switcher.set_valign(Gtk.Align.CENTER)
        self.matugen_switcher.set_halign(Gtk.Align.CENTER)
        self.matugen_switcher.set_active(self.matugen_enabled)
        self.matugen_switcher.connect("notify::active", self.on_switch_toggled)
        self.mat_icon = Label(name="mat-label", markup=icons.palette)
        self.random_wall = Button(
            name="random-wall-button",
            child=Label(name="random-wall-label", markup=icons.dice_1),
            tooltip_text="Random Wallpaper",
        )
        self.random_wall.connect("clicked", self.set_random_wallpaper)

        # Add label to display current wallpaper name and directory
        self.current_wallpaper_label = Label(
            name="current-wallpaper-label",
            label="Current Wallpaper: None",
            h_align="center",
            h_expand=True
        )

        # Create a vertical box to hold search entry and current wallpaper label
        self.search_container = Box(
            name="search-container",
            orientation="v",
            spacing=4,
            h_expand=True,
            h_align="fill",
            children=[self.search_entry] #, self.current_wallpaper_label]
        )

        self.header_box = Box(
            name="header-box",
            spacing=8,
            orientation="h",
            children=[
                self.random_wall,
                self.search_container,
                self.scheme_dropdown,
                self.matugen_switcher
            ],
        )
        self.add(self.header_box)
        self.add(self.current_wallpaper_label)
        self.prev_button = Button(label="Previous", name="prev-page-button")
        self.prev_button.connect("clicked", self.on_prev_clicked)
        self.next_button = Button(label="Next", name="next-page-button")
        self.next_button.connect("clicked", self.on_next_clicked)
        self.page_label = Label(label=f"Page {self.current_page + 1} of {self.total_pages}", name="page-label")
        self.pagination_box = Box(
            name="pagination-box",
            orientation="h",
            spacing=5,
            h_align="center",
            children=[self.prev_button, self.page_label, self.next_button],
        )
        self.pagination_box.show_all()

        self.hue_slider = Gtk.Scale(
            orientation=Gtk.Orientation.HORIZONTAL,
            adjustment=Gtk.Adjustment(value=0, lower=0, upper=360, step_increment=1, page_increment=10),
            draw_value=False,
            digits=0,
            name="hue-slider",
        )
        self.hue_slider.set_hexpand(True)
        self.hue_slider.set_halign(Gtk.Align.FILL)
        self.hue_slider.set_vexpand(False)
        self.hue_slider.set_valign(Gtk.Align.CENTER)
        self.apply_color_button = Button(name="apply-color-button", child=Label(name="apply-color-label", markup=icons.accept))
        self.apply_color_button.connect("clicked", self.on_apply_color_clicked)
        self.apply_color_button.set_vexpand(False)
        self.apply_color_button.set_valign(Gtk.Align.CENTER)
        self.custom_color_selector_box = Box(
            orientation="h", spacing=5, name="custom-color-selector-box",
            h_align="center"
        )
        self.custom_color_selector_box.add(self.hue_slider)
        self.custom_color_selector_box.add(self.apply_color_button)
        self.custom_color_selector_box.set_halign(Gtk.Align.FILL)
        self.pack_start(self.scrolled_window, True, True, 0)
        self.pack_start(self.pagination_box, False, False, 0)
        self.pack_start(self.custom_color_selector_box, False, False, 0)

        self._load_page(self.current_page)
        self.update_current_wallpaper_label()

        self.connect("map", self.on_map)
        self.setup_file_monitor()
        self.show_all()
        self.randomize_dice_icon()
        self.search_entry.grab_focus()

    def update_current_wallpaper_label(self):
        """Updates the label to show the current wallpaper's name and directory."""
        current_wall = os.path.expanduser("~/.current.wall")
        try:
            if os.path.islink(current_wall) or os.path.isfile(current_wall):
                full_path = os.readlink(current_wall) if os.path.islink(current_wall) else current_wall
                if os.path.exists(full_path):
                    wallpaper_name = os.path.basename(full_path)
                    wallpaper_dir = os.path.dirname(full_path)
                    self.current_wallpaper_label.set_label(f"Current: {wallpaper_name} ({wallpaper_dir})")
                else:
                    self.current_wallpaper_label.set_label("Current Wallpaper: Not found")
            else:
                self.current_wallpaper_label.set_label("Current Wallpaper: None")
        except Exception as e:
            print(f"Error reading current wallpaper: {e}")
            self.current_wallpaper_label.set_label("Current Wallpaper: Error")

    def on_prev_clicked(self, button):
        if self.is_searching:
            if self.search_current_page > 0:
                self.search_current_page -= 1
                self._load_search_page(self.search_current_page)
        else:
            if self.current_page > 0:
                self.current_page -= 1
                self._load_page(self.current_page)

    def on_next_clicked(self, button):
        if self.is_searching:
            if self.search_current_page < self.search_total_pages - 1:
                self.search_current_page += 1
                self._load_search_page(self.search_current_page)
        else:
            if self.current_page < self.total_pages - 1:
                self.current_page += 1
                self._load_page(self.current_page)

    def _get_files_recursive(self, directory: str) -> list[str]:
        image_files = []
        try:
            for root, _, filenames in os.walk(directory):
                for filename in filenames:
                    full_path = os.path.join(root, filename)
                    if self._is_image(full_path):
                        image_files.append(full_path)
            image_files.sort(key=lambda x: os.path.basename(x).lower())
        except Exception as e:
            print(f"Error getting files recursively from {directory}: {e}")
        return image_files

    def _load_page(self, page: int):
        if not 0 <= page < self.total_pages and self.files:
            return

        self.current_page = page
        model = self.viewport.get_model()
        model.clear()
        self.thumbnails.clear()
        self.selected_index = -1

        start = page * self.page_size
        end = min(start + self.page_size, len(self.files))

        batch_files = self.files[start:end]

        futures = [self.executor.submit(self._process_file_for_thumb, file_path) for file_path in batch_files]
        results = [future.result() for future in futures]

        GLib.idle_add(self._add_batch_thumbnails, results)

        self.update_pagination_ui()

    def _load_search_page(self, page: int):
        if not 0 <= page < self.search_total_pages or not self.search_files:
            return

        self.search_current_page = page
        model = self.viewport.get_model()
        model.clear()
        self.thumbnails.clear()
        self.selected_index = -1

        start = page * self.search_page_size
        end = min(start + self.search_page_size, len(self.search_files))

        batch_files = self.search_files[start:end]

        futures = [self.executor.submit(self._process_file_for_thumb, file_path) for file_path in batch_files]
        results = [future.result() for future in futures]

        GLib.idle_add(self._add_batch_thumbnails, results)

        self.update_pagination_ui()

    def _add_batch_thumbnails(self, results):
        model = self.viewport.get_model()
        for result in results:
            if result is None:
                continue
            cache_path, full_path = result
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(cache_path)
                display_name = os.path.relpath(full_path, data.WALLPAPERS_DIR)
                model.append([pixbuf, full_path, display_name])
            except Exception as e:
                print(f"Error adding thumbnail {cache_path}: {e}")

        if len(model) > 0 and self.selected_index == -1:
            self.update_selection(0)

        return False

    def update_pagination_ui(self):
        if self.is_searching and len(self.search_files) == 0:
            self.page_label.set_label("No results found")
            self.prev_button.set_sensitive(False)
            self.next_button.set_sensitive(False)
            return

        if self.is_searching:
            page_num = self.search_current_page + 1
            total_p = self.search_total_pages
        else:
            page_num = self.current_page + 1
            total_p = self.total_pages

        self.page_label.set_label(f"Page {page_num} of {total_p}")
        current_p = self.search_current_page if self.is_searching else self.current_page
        total_p = self.search_total_pages if self.is_searching else self.total_pages
        self.prev_button.set_sensitive(current_p > 0)
        self.next_button.set_sensitive(current_p < total_p - 1)

    def randomize_dice_icon(self):
        dice_icons = [
            icons.dice_1,
            icons.dice_2,
            icons.dice_3,
            icons.dice_4,
            icons.dice_5,
            icons.dice_6,
        ]
        chosen_icon = random.choice(dice_icons)
        label = self.random_wall.get_child()
        if isinstance(label, Label):
            label.set_markup(chosen_icon)

    def _is_grayscale(self, image_path: str) -> bool:
        """Check if the image is grayscale (black and white)."""
        try:
            with Image.open(image_path) as img:
                # Convert to RGB if not already
                img = img.convert("RGB")
                # Sample pixels to check for grayscale
                pixels = img.getdata()
                for r, g, b in pixels:
                    # If R, G, B values are not equal, it's not grayscale
                    if r != g or g != b:
                        return False
                return True
        except Exception as e:
            print(f"Error checking if image is grayscale: {e}")
            return False

    def _set_wallpaper_from_path(self, full_path: str):
        selected_scheme = self.scheme_dropdown.get_active_id()
        # Check if the image is grayscale
        if selected_scheme == "scheme-content" and self._is_grayscale(full_path):
            print(f"Grayscale image detected, falling back to 'monochrome' scheme for {full_path}")
            selected_scheme = "scheme-monochrome"  # Fallback to monochrome scheme

        current_wall = os.path.expanduser("~/.current.wall")
        if os.path.isfile(current_wall) or os.path.islink(current_wall):
            os.remove(current_wall)
        os.symlink(full_path, current_wall)
        if self.matugen_switcher.get_active():
            exec_shell_command_async(f'matugen image "{full_path}" -t {selected_scheme}')
        else:
            exec_shell_command_async(
                f'swww img "{full_path}" -t outer --transition-duration 1.5 --transition-step 255 --transition-fps 60 -f Nearest'
            )
        print(f"Set wallpaper: {os.path.basename(full_path)}")
        self.update_current_wallpaper_label()

    def set_random_wallpaper(self, widget, external=False):
        if not self.files:
            print("No wallpapers available to set a random one.")
            return
        full_path = random.choice(self.files)
        self._set_wallpaper_from_path(full_path)
        if external:
            exec_shell_command_async(f"notify-send '🎲 Wallpaper' 'Setting a random wallpaper 🎨' -a '{data.APP_NAME_CAP}' -i '{full_path}' -e")
        self.randomize_dice_icon()
        self.search_entry.grab_focus() # Add this line

    def setup_file_monitor(self):
        gfile = Gio.File.new_for_path(data.WALLPAPERS_DIR)
        self.file_monitor = gfile.monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        self.file_monitor.connect("changed", self.on_directory_changed)

    def on_directory_changed(self, monitor, file, other_file, event_type):
        print(f"Directory change detected: {event_type.value_nick}, refreshing wallpapers...")
        GLib.idle_add(self.refresh_wallpaper_list)

    def refresh_wallpaper_list(self):
        self.files.clear()
        self.thumbnails.clear()
        self.viewport.get_model().clear()
        self.files = self._get_files_recursive(data.WALLPAPERS_DIR)
        self.total_pages = math.ceil(len(self.files) / self.page_size) if self.files else 1
        self.current_page = 0
        self._load_page(self.current_page)
        self.arrange_viewport(self.search_entry.get_text())
        self.update_current_wallpaper_label()
        return False

    def arrange_viewport(self, query: str = ""):
        query = query.strip()
        if hasattr(self, "last_query") and query == self.last_query:
            return  # Ignore redundant triggers
        self.last_query = query

        if self.search_timeout_id:
            GLib.source_remove(self.search_timeout_id)
            self.search_timeout_id = None

        if not query:
            if self.is_searching:
                self.is_searching = False
            self.pagination_box.show()
            self._load_page(self.current_page)
            return

        self.is_searching = True
        self.pagination_box.show()
        self.search_timeout_id = GLib.timeout_add(500, self._start_threaded_search, query)

    def _start_threaded_search(self, query: str):
        self.search_timeout_id = None
        future = self.executor.submit(self._perform_fuzzy_search, query)
        future.add_done_callback(lambda f: GLib.idle_add(self._update_search_results, f))
        return False

    def _perform_fuzzy_search(self, query: str) -> list[str]:
        query_lower = query.casefold().strip()
        if not query_lower:
            return []

        matching = []
        for file_path in self.files:
            display_name = os.path.relpath(file_path, data.WALLPAPERS_DIR).casefold()
            if query_lower in display_name:
                matching.append(file_path)

        matching.sort(key=lambda x: os.path.basename(x).lower())
        return matching

    def _update_search_results(self, future: concurrent.futures.Future):
        model = self.viewport.get_model()
        model.clear()
        self.thumbnails.clear()
        self.selected_index = -1

        try:
            self.search_files = future.result()
            self.search_total_pages = math.ceil(len(self.search_files) / self.search_page_size) if self.search_files else 0
            if self.search_total_pages == 0:
                self.page_label.set_label("No results found")
                self.prev_button.set_sensitive(False)
                self.next_button.set_sensitive(False)
                self.viewport.unselect_all()
                self.selected_index = -1
            else:
                self._load_search_page(0)
        except Exception as e:
            print(f"Error getting search results: {e}")
            self.page_label.set_label("Search error")
            self.prev_button.set_sensitive(False)
            self.next_button.set_sensitive(False)
            self.viewport.unselect_all()
            self.selected_index = -1

        return False

    def on_wallpaper_selected(self, iconview, path):
        model = iconview.get_model()
        full_path = model[path][1]
        self._set_wallpaper_from_path(full_path)
        self.search_entry.grab_focus() # Add this line

    def on_scheme_changed(self, combo):
        selected_scheme = combo.get_active_id()
        print(f"Color scheme selected: {selected_scheme}")

    def on_search_entry_key_press(self, widget, event):
        if event.state & Gdk.ModifierType.SHIFT_MASK:
            if event.keyval in (Gdk.KEY_Up, Gdk.KEY_Down):
                schemes_list = list(self.schemes.keys())
                current_id = self.scheme_dropdown.get_active_id()
                current_index = schemes_list.index(current_id) if current_id in schemes_list else 0
                new_index = (current_index - 1) % len(schemes_list) if event.keyval == Gdk.KEY_Up else (current_index + 1) % len(schemes_list)
                self.scheme_dropdown.set_active(new_index)
                return True
            elif event.keyval == Gdk.KEY_Right:
                self.scheme_dropdown.popup()
                return True

        if event.keyval in (Gdk.KEY_Up, Gdk.KEY_Down, Gdk.KEY_Left, Gdk.KEY_Right):
            self.move_selection_2d(event.keyval)
            return True
        elif event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            if self.selected_index != -1:
                model = self.viewport.get_model()
                path = Gtk.TreePath.new_from_indices([self.selected_index])
                iter_obj = model.get_iter(path)
                if iter_obj:
                    full_path = model.get_value(iter_obj, 1)
                    self._set_wallpaper_from_path(full_path)
            return True
        return False

    def move_selection_2d(self, keyval):
        model = self.viewport.get_model()
        total_items = len(model)
        if total_items == 0:
            return

        columns = self._get_columns(total_items)
        current_index = self.selected_index
        new_index = self._get_new_index(keyval, current_index, columns, total_items)

        if new_index == "prev_page":
            self.on_prev_clicked(None)
            return
        elif new_index == "next_page":
            self.on_next_clicked(None)
            return

        if 0 <= new_index < total_items and new_index != self.selected_index:
            self.update_selection(new_index)
        elif total_items > 0 and self.selected_index == -1 and 0 <= new_index < total_items:
            self.update_selection(new_index)

    def _get_columns(self, total_items):
        columns = self.viewport.get_columns()
        if columns > 0:
            return columns

        if total_items == 0:
            return 1

        try:
            first_item_path = Gtk.TreePath.new_from_indices([0])
            base_row = self.viewport.get_item_row(first_item_path)
            for i in range(1, total_items):
                path = Gtk.TreePath.new_from_indices([i])
                row = self.viewport.get_item_row(path)
                if row > base_row:
                    return max(1, i)
            return max(1, total_items)
        except Exception:
            return 1

    def _get_new_index(self, keyval, current_index, columns, total_items):
        if current_index == -1:
            if keyval in (Gdk.KEY_Down, Gdk.KEY_Right):
                return 0
            elif keyval in (Gdk.KEY_Up, Gdk.KEY_Left):
                return total_items - 1
            return -1

        if keyval == Gdk.KEY_Up:
            return current_index - columns if current_index - columns >= 0 else current_index
        elif keyval == Gdk.KEY_Down:
            return current_index + columns if current_index + columns < total_items else current_index
        elif keyval == Gdk.KEY_Left:
            if current_index > 0:
                return current_index - 1
            else:
                if self.is_searching:
                    if self.search_current_page > 0:
                        return "prev_page"
                else:
                    if self.current_page > 0:
                        return "prev_page"
                return current_index
        elif keyval == Gdk.KEY_Right:
            if current_index < total_items - 1:
                return current_index + 1
            else:
                if self.is_searching:
                    if self.search_current_page < self.search_total_pages - 1:
                        return "next_page"
                else:
                    if self.current_page < self.total_pages - 1:
                        return "next_page"
                return current_index
        return current_index

    def update_selection(self, new_index: int):
        self.viewport.unselect_all()
        path = Gtk.TreePath.new_from_indices([new_index])
        self.viewport.select_path(path)
        self.viewport.scroll_to_path(path, False, 0.5, 0.5)
        self.selected_index = new_index

    def _get_cache_path(self, full_path: str) -> str:
        try:
            mtime = os.path.getmtime(full_path)
        except FileNotFoundError:
            mtime = 0.0

        unique_key = f"{full_path}-{mtime}"
        file_hash = hashlib.md5(unique_key.encode("utf-8")).hexdigest()
        return os.path.join(self.CACHE_DIR, f"{file_hash}.png")

    def _process_file_for_thumb(self, full_path: str):
        cache_path = self._get_cache_path(full_path)
        if not os.path.exists(cache_path):
            try:
                with Image.open(full_path) as img:
                    width, height = img.size
                    side = min(width, height)
                    left = (img.width - side) // 2
                    top = (height - side) // 2
                    right = left + side
                    bottom = top + side
                    img_cropped = img.crop((left, top, right, bottom))
                    img_cropped.thumbnail((96, 96), Image.Resampling.LANCZOS)
                    img_cropped.save(cache_path, "PNG")
            except Exception as e:
                print(f"Error processing {full_path}: {e}")
                return None
        return cache_path, full_path

    @staticmethod
    def _is_image(file_path: str) -> bool:
        return os.path.basename(file_path).lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'))

    def on_map(self, widget):
        self.custom_color_selector_box.set_visible(not self.matugen_enabled)
        self.search_entry.set_text("")
        self.is_searching = False
        self.pagination_box.show_all()
        self.current_page = 0
        self._load_page(self.current_page)
        self.update_current_wallpaper_label()
        self.search_entry.grab_focus()

    def hsl_to_rgb_hex(self, h: float, s: float = 1.0, l: float = 0.5) -> str:
        hue = h / 360.0
        r, g, b = colorsys.hls_to_rgb(hue, l, s)
        r_int, g_int, b_int = int(r * 255), int(g * 255), int(b * 255)
        return f"#{r_int:02X}{g_int:02X}{b_int:02X}"

    def rgba_to_hex(self, rgba: Gdk.RGBA) -> str:
        r = int(rgba.red * 255)
        g = int(rgba.green * 255)
        b = int(rgba.blue * 255)
        return f"#{r:02X}{g:02X}{b:02X}"

    def on_switch_toggled(self, switch, gparam):
        is_active = switch.get_active()
        self.matugen_enabled = is_active
        self.custom_color_selector_box.set_visible(not is_active)
        try:
            with open(data.MATUGEN_STATE_FILE, 'w') as f:
                f.write(str(is_active))
        except Exception as e:
            print(f"Error writing matugen state file: {e}")

    def on_apply_color_clicked(self, button):
        hue_value = self.hue_slider.get_value()
        hex_color = self.hsl_to_rgb_hex(hue_value)
        print(f"Applying color from slider: H={hue_value}, HEX={hex_color}")
        selected_scheme = self.scheme_dropdown.get_active_id()
        exec_shell_command_async(f'matugen color hex "{hex_color}" -t {selected_scheme}')