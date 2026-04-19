import AstalWp from "gi://AstalWp";
import GLib from "gi://GLib";
import Astal from "gi://Astal?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import Cairo from "gi://cairo";

export default function VolumePopup({ gdkmonitor }: { gdkmonitor: any }) {
  const speaker = AstalWp.get_default()?.audio.defaultSpeaker;
  if (!speaker) return <box />;

  let timeoutId: number | null = null;

  const init = (
    revealer: Gtk.Revealer,
    levelbar: Gtk.LevelBar,
    percentLabel: Gtk.Label
  ) => {
    let speakerVolSignal: number | null = null;
    let speakerMuteSignal: number | null = null;
    let pollId: number | null = null;

    const window = revealer.get_root() as Gtk.Window;
    if (!window) return;

    const container = revealer.get_child() as Gtk.Box;

    const micIcon = container.get_first_child() as Gtk.Image;
    const speakerIcon = micIcon.get_next_sibling() as Gtk.Image;

    let micMuted = false;
    let lastMicMute: boolean | null = null;

    let ready = false;
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => {
      ready = true;
      return GLib.SOURCE_REMOVE;
    });

    const clearTimeoutSafe = () => {
      if (timeoutId) {
        GLib.source_remove(timeoutId);
        timeoutId = null;
      }
    };

    // =========================
    // UI MODES (FIX)
    // =========================
    const setMicMode = () => {
      micIcon.set_visible(true);
      speakerIcon.set_visible(false);

      levelbar.set_visible(false);
      percentLabel.set_visible(false);
    };

    const setVolumeMode = () => {
      micIcon.set_visible(false);
      speakerIcon.set_visible(true);

      levelbar.set_visible(true);
      percentLabel.set_visible(true);
    };

    const updateUI = () => {
      const vol = speaker.mute ? 0 : speaker.volume;

      levelbar.value = Math.min(vol, 1);
      percentLabel.set_text(`${Math.round(vol * 100)}%`);

      speakerIcon.set_from_icon_name(
        speaker.mute
          ? "audio-volume-muted-symbolic"
          : speaker.volume > 0.5
            ? "audio-volume-high-symbolic"
            : speaker.volume > 0.1
              ? "audio-volume-medium-symbolic"
              : "audio-volume-low-symbolic"
      );
    };

    updateUI();

    // =========================
    // VOLUME POPUP
    // =========================
    const showVolume = () => {
      if (!window || !ready) return;

      if (speaker.mute) {
        updateUI();
        return;
      }

      clearTimeoutSafe();

      setVolumeMode();
      updateUI();

      if (!window.visible) window.set_visible(true);

      revealer.reveal_child = true;

      timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
        revealer.reveal_child = false;

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
          if (!revealer.reveal_child && window) {
            window.set_visible(false);
          }
          return GLib.SOURCE_REMOVE;
        });

        timeoutId = null;
        return GLib.SOURCE_REMOVE;
      });
    };

    // =========================
    // MIC POPUP
    // =========================
    const showMic = () => {
      if (!window || !ready) return;

      micIcon.set_from_icon_name(
        micMuted
          ? "microphone-disabled-symbolic"
          : "microphone-sensitivity-high-symbolic"
      );

      if (micMuted) {
        container.add_css_class("mic-muted");
      } else {
          container.remove_css_class("mic-muted");
      }

      setMicMode(); // 🔥 IMPORTANT FIX

      if (!window.visible) window.set_visible(true);

      revealer.reveal_child = true;

      clearTimeoutSafe();

      if (micMuted) return;

      timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        revealer.reveal_child = false;

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
          if (!revealer.reveal_child && window) {
            window.set_visible(false);
          }
          return GLib.SOURCE_REMOVE;
        });

        timeoutId = null;
        return GLib.SOURCE_REMOVE;
      });
    };

    // =========================
    // EVENTS
    // =========================
    speakerVolSignal = speaker.connect("notify::volume", () => {
      showVolume();
    });

    speakerMuteSignal = speaker.connect("notify::mute", () => {
      if (!ready) return;

      clearTimeoutSafe();
      updateUI();

      if (speaker.mute) {
        setVolumeMode(); // keep layout stable

        if (!window.visible) window.set_visible(true);

        revealer.reveal_child = true;

        timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => {
          revealer.reveal_child = false;

          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
            if (!revealer.reveal_child && window) {
              window.set_visible(false);
            }
            return GLib.SOURCE_REMOVE;
          });

          timeoutId = null;
          return GLib.SOURCE_REMOVE;
        });

        return;
      }

      showVolume();
    });

    // =========================
    // MIC POLL
    // =========================
    pollId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
      try {
        const [, out] = GLib.spawn_command_line_sync(
          "pamixer --default-source --get-mute"
        );

        const isMuted = new TextDecoder().decode(out).trim() === "true";

        if (isMuted !== lastMicMute) {
          lastMicMute = isMuted;
          micMuted = isMuted;

          if (ready) showMic();
        }
      } catch {}

      return GLib.SOURCE_CONTINUE;
    });

    revealer.connect("destroy", () => {
      clearTimeoutSafe();

      if (pollId) GLib.source_remove(pollId);
      if (speakerVolSignal) speaker.disconnect(speakerVolSignal);
      if (speakerMuteSignal) speaker.disconnect(speakerMuteSignal);
    });
  };

  return (
    <window
      gdkmonitor={gdkmonitor}
      name={`volume-popup-${gdkmonitor.connector}`}
      cssClasses={["VolumePopup"]}
      namespace="volume-popup"
      anchor={Astal.WindowAnchor.BOTTOM}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
      visible={false}
      $={(self) => {
        const region = new Cairo.Region();
        self.input_region = region;
      }}
    >
      <revealer
        transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
        reveal_child={false}
        transitionDuration={300}
        valign={Gtk.Align.END}
        $={(self) => {
          GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            const box = self.get_child() as Gtk.Box;

            const levelbar = box.get_last_child() as Gtk.LevelBar;

            const percentLabel = new Gtk.Label({ label: "0%" });
            box.append(percentLabel);

            init(self, levelbar, percentLabel);

            return GLib.SOURCE_REMOVE;
          });
        }}
      >
        <box
          cssClasses={["container"]}
          valign={Gtk.Align.END}
          orientation={Gtk.Orientation.HORIZONTAL}
          spacing={12}
        >
          <image iconName={"microphone-disabled-symbolic"} />
          <image iconName={"audio-volume-high-symbolic"} />

          <levelbar
            valign={Gtk.Align.CENTER}
            halign={Gtk.Align.FILL}
            hexpand={true}
            widthRequest={150}
            heightRequest={6}
            minValue={0}
            maxValue={1}
            mode={Gtk.LevelBarMode.CONTINUOUS}
          />
        </box>
      </revealer>
    </window>
  );
}