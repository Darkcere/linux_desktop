import { createBinding, For, This } from "ags";
import app from "ags/gtk4/app";
import Gio from "gi://Gio";
import GLib from "gi://GLib";
import Gtk from "gi://Gtk?version=4.0";
import Bar from "./Bar";
import VolumePopup from "./Widgets/VolumePopup";
import BrightnessPopup from "./Widgets/BrightnessPopup";
import UpdatePopup from "./Widgets/Updatepopup";
import SettingsWindow from "./Widgets/Settings";
import Applauncher from "./Widgets/Applauncher";
import PowerMenu from "./Widgets/PowerMenu";
import MusicPopup from "./Widgets/BottomPopup";
import { toggleEditMode, editMode } from "./State";

const configDir = `${GLib.get_user_config_dir()}/ags`;
const STYLE_PATH = `${configDir}/style.css`;
const MATUGEN_DIR = `${GLib.get_home_dir()}/.config/ags`;

app.start({
  instanceName: "synapse",
  css: STYLE_PATH,

  requestHandler(argv, res) {
    if (argv[0] === "toggle") {
      const _app: any = app;
      if (_app.applauncherWin) {
        _app.applauncherWin.visible = !_app.applauncherWin.visible;
        if (_app.applauncherWin.visible) _app.applauncherWin.present();
        return res("ok");
      }
      return res("launcher not initialized");
    }

    if (argv[0] === "RightSidebar") {
      const monitors = app.get_monitors();
      if (monitors.length > 0) {
        const connector = monitors[0].connector;
        app.toggle_window(`RightSidebar-${connector}`);
        return res("ok");
      }
      return res("no monitors found");
    }

    if (argv[0] === "toggle-powermenu") {
      const monitors = app.get_monitors();
      monitors.forEach((m) =>
        app.toggle_window(`powermenu-${m.connector}`)
      );
      return res("ok");
    }

    if (argv[0] === "toggle-edit-mode") {
      toggleEditMode();
      return res(
        `ok - edit mode is now ${
          editMode.get() ? "enabled" : "disabled"
        }`,
      );
    }

    if (argv[0] === "music-popup") {
      const monitors = app.get_monitors();
      monitors.forEach((m) =>
        app.toggle_window(`music-popup-${m.connector}`)
      );
      return res("ok");
    }

    return res("unknown command");
  },

  main() {
    const _app: any = app;

    // ----------------------------
    // APP LAUNCHER
    // ----------------------------
    const launcherWin = Applauncher() as Gtk.Window;
    launcherWin.visible = false;
    launcherWin.hide();
    app.add_window(launcherWin);
    _app.applauncherWin = launcherWin;

    // ----------------------------
    // FILE WATCHER (SMART HOT RELOAD)
    // ----------------------------
    const dir = Gio.File.new_for_path(MATUGEN_DIR);

    let lastHashes = new Map<string, string>();

    const hashFile = (path: string) => {
      try {
        const file = Gio.File.new_for_path(path);
        const [, contents] = file.load_contents(null);
        return new TextDecoder().decode(contents);
      } catch {
        return "";
      }
    };

    const reloadCSS = () => {
      try {
        app.apply_css(STYLE_PATH);
        console.log("🔥 CSS reloaded");
      } catch (e) {
        console.error("CSS reload failed:", e);
      }
    };

    const checkChange = (filePath: string) => {
      const content = hashFile(filePath);
      const old = lastHashes.get(filePath);

      if (old !== content) {
        lastHashes.set(filePath, content);
        reloadCSS();
      }
    };

    try {
      _app.fileMonitor = dir.monitor_directory(
        Gio.FileMonitorFlags.NONE,
        null,
      );

      _app.fileMonitor.connect("changed", (_self: any, file: any) => {
        const name = file.get_basename();

        // only care about CSS
        if (name !== "style.css" && name !== "colors.css") return;

        const path = `${MATUGEN_DIR}/${name}`;

        // small delay so file write finishes
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
          checkChange(path);
          return GLib.SOURCE_REMOVE;
        });
      });
    } catch (e) {
      console.error("File monitor failed:", e);
    }

    // ----------------------------
    // WINDOWS
    // ----------------------------
    const monitors = createBinding(app, "monitors");

    return (
      <For each={monitors}>
        {(gdkmonitor) => (
          <This this={app}>
            <Bar gdkmonitor={gdkmonitor} />
            <SettingsWindow gdkmonitor={gdkmonitor} />
            <VolumePopup gdkmonitor={gdkmonitor} />
            <BrightnessPopup gdkmonitor={gdkmonitor} />
            <UpdatePopup gdkmonitor={gdkmonitor} />
            <PowerMenu gdkmonitor={gdkmonitor} />
            <MusicPopup gdkmonitor={gdkmonitor} />
          </This>
        )}
      </For>
    );
  },
});