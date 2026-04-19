import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk";
import AstalTray from "gi://AstalTray";
import { For, createBinding } from "ags";

export default function Tray() {
  const tray = AstalTray.get_default();
  const items = createBinding(tray, "items");

  const init = (btn: Gtk.MenuButton, item: AstalTray.TrayItem) => {
    btn.menuModel = null;

    const popover = new Gtk.PopoverMenu({
      menu_model: item.menuModel,
      has_arrow: false,
    });

    popover.set_parent(btn);
    btn.set_popover(popover);

    btn.insert_action_group("dbusmenu", item.actionGroup);

    const gesture = new Gtk.GestureClick();
    gesture.set_button(3);

    gesture.connect("pressed", () => {
      popover.popup();
    });

    btn.add_controller(gesture);

    item.connect("notify::action-group", () => {
      btn.insert_action_group("dbusmenu", item.actionGroup);
    });
  };

  return (
    <box cssClasses={["tray"]} valign={Gtk.Align.CENTER}>
      {/* 👇 Group container */}
      <box cssClasses={["tray-group"]} valign={Gtk.Align.CENTER}>
        <For each={items}>
          {(item) => (
            <menubutton
              $={(self) => init(self, item)}
              cssClasses={["tray-item"]}
              heightRequest={24}
              valign={Gtk.Align.CENTER}
            >
              <image gicon={createBinding(item, "gicon")} />
            </menubutton>
          )}
        </For>
      </box>
    </box>
  );
}