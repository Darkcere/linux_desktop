import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") {
                Hyprland.refreshToplevels();
            }
        }
    }
    
    property bool realFullscreen: {
        let workspaceHasFs = Hyprland.focusedWorkspace?.hasFullscreen ?? false;
        if (!workspaceHasFs) return false;

        let active = Hyprland.activeToplevel;
        return active?.lastIpcObject?.fullscreen === 2;
    }

    property bool isRightMenuOpen: {
        let menu = dropdownLoader.item;
        if (!menu) return false;
        return menu.isOpen && (menu.activeView === "tray" || menu.activeView === "audio" || menu.activeView === "notifications");
    }

    // 💡 THE FIX: Safe root property to track the Bar state!
    property bool isBarActive: true
    // 💡 THE FIX: A reactive token to safely trigger updates across Loaders
    property string wallpaperToken: ""

    // 💡 THE FIX: Moved the Bash execution to the root so it never gets blocked
    function applySystemColors() {
        let colorCmd = `matugen --source-color-index 0 image "$HOME/.current.wall" -t scheme-content && sh "$HOME/.config/hypr/scripts/colors_mqtt.sh"`;
        Quickshell.execDetached({ command: ["bash", "-c", colorCmd] });
    }
    // 💡 THE FIX: Use dropdownLoader.item to force the load if pressed early
    GlobalShortcut { name: "toggleTools"; onPressed: dropdownLoader.item.toggleTools() }
    GlobalShortcut { name: "togglePowerMenu"; onPressed: dropdownLoader.item.togglePowerMenu() }
    GlobalShortcut { name: "toggleClipboard"; onPressed: dropdownLoader.item.toggleClipboard() }
    GlobalShortcut { name: "toggleLauncher"; onPressed: dropdownLoader.item.toggleApps() }
    GlobalShortcut { name: "toggleWallpaperPicker"; onPressed: dropdownLoader.item.openWallpaperPicker() }
    GlobalShortcut { name: "toggleAudioMenu"; onPressed: dropdownLoader.item.toggleAudio() }
    GlobalShortcut { name: "toggleNotifications"; onPressed: dropdownLoader.item.toggleNotifications() }
    
    GlobalShortcut {
        name: "toggleBar"
        // 💡 THE FIX: Toggle the root property, not the window directly
        onPressed: root.isBarActive = !root.isBarActive
    }
    GlobalShortcut {
        name: "updateWallpaper"
        onPressed: {
            root.applySystemColors();
            root.wallpaperToken = Date.now().toString();
        }
    }
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
    }

    // 💡 THE LOADER: Wraps the entire Bar component.
    // When isBarActive is false, the Wayland PanelWindow and all its heavy modules 
    // (Tray, Media Player, Workspaces) are completely deleted from RAM.
    Loader {
        active: root.isBarActive && !root.realFullscreen
        sourceComponent: Component {
            Bar {
                menuHandler: dropdownLoader.item 
                isDropdownOpen: dropdownLoader.item?.isOpen ?? false
                dropdownWidth: dropdownLoader.item?.currentDropWidth ?? 0
                onToggleLauncherRequested: dropdownLoader.item?.toggleApps()
            }
        }
    }
    LazyLoader {
        id: popupsLoader
        loading: true
        NotificationPopup {
            id: popups
            isBarVisible: !root.realFullscreen && root.isBarActive && !dropdownLoader.item?.isOpen
            dropdownOffset: root.isRightMenuOpen ? ((dropdownLoader.item?.currentDropHeight ?? 0) + 10) : 0
        }
    }
    LazyLoader {
        id: dropdownLoader
        loading: true // Boot in the background immediately
        
        DropdownWindow {
            isBarVisible: !root.realFullscreen && root.isBarActive
        }
    }
    LazyLoader {
        id: osdloader
        loading: true
        Osd {
            id: volumeOSD
        }
    }
    LazyLoader {
        id: wallpaperLoader
        loading: !root.realFullscreen
        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            Item {
                id: wallpaperContainer
                anchors.fill: parent
                property bool useFront: false
                // 💡 THE FIX: Safely listen to the root token for updates!
                Connections {
                    target: root
                    function onWallpaperTokenChanged() {
                        if (root.wallpaperToken === "init") return;
                        
                        let newUrl = "file://" + Quickshell.env("HOME") + "/.current.wall?t=" + root.wallpaperToken;
                        if (wallpaperContainer.useFront) {
                            backImage.source = newUrl;
                        } else {
                            frontImage.source = newUrl;
                        }
                    }
                }
                Image {
                    id: backImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false 
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                    source: "file://" + Quickshell.env("HOME") + "/.current.wall"
                    
                    onStatusChanged: {
                        if (status === Image.Ready && wallpaperContainer.useFront) {
                            wallpaperContainer.useFront = false;
                        }
                    }
                }
                Image {
                    id: frontImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false 
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                    source: ""
                    opacity: wallpaperContainer.useFront ? 1 : 0
                    
                    Behavior on opacity {
                        NumberAnimation { 
                            duration: 500; 
                            easing.type: Easing.InOutQuad 
                            onStopped: {
                                if (frontImage.opacity === 1) { backImage.source = "" } 
                                else if (frontImage.opacity === 0) { frontImage.source = "" }
                            }
                        }
                    }
                    onStatusChanged: {
                        if (status === Image.Ready && !wallpaperContainer.useFront && source !== "") {
                            wallpaperContainer.useFront = true;
                        }
                    }
                }
            }
        }
    
    }
}