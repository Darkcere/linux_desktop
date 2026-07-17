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

    property bool isRightMenuOpen: dropdownManager.isOpen && 
                                   (dropdownManager.activeView === "tray" || 
                                    dropdownManager.activeView === "audio" || 
                                    dropdownManager.activeView === "notifications")

    // 💡 THE FIX: Safe root property to track the Bar state!
    property bool isBarActive: true

    GlobalShortcut { name: "toggleTools"; onPressed: dropdownManager.toggleTools() }
    GlobalShortcut { name: "togglePowerMenu"; onPressed: dropdownManager.togglePowerMenu() }
    GlobalShortcut { name: "toggleClipboard"; onPressed: dropdownManager.toggleClipboard() }
    GlobalShortcut { name: "toggleLauncher"; onPressed: dropdownManager.toggleApps() }
    GlobalShortcut { name: "toggleWallpaperPicker"; onPressed: dropdownManager.openWallpaperPicker() }
    GlobalShortcut { name: "toggleAudioMenu"; onPressed: dropdownManager.toggleAudio() }
    GlobalShortcut { name: "toggleNotifications"; onPressed: dropdownManager.toggleNotifications() }
    
    GlobalShortcut {
        name: "toggleBar"
        // 💡 THE FIX: Toggle the root property, not the window directly
        onPressed: root.isBarActive = !root.isBarActive
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
                menuHandler: dropdownManager 
                isDropdownOpen: dropdownManager.isOpen 
                dropdownWidth: dropdownManager.currentDropWidth
                onToggleLauncherRequested: dropdownManager.toggleApps()
            }
        }
    }

    NotificationPopup {
        id: popups
        // 💡 THE FIX: Bind to the safe root property
        isBarVisible: !root.realFullscreen && root.isBarActive
        dropdownOffset: root.isRightMenuOpen ? (dropdownManager.currentDropHeight + 10) : 0
    }

    DropdownWindow {
        id: dropdownManager
        // 💡 THE FIX: Bind to the safe root property
        isBarVisible: !root.realFullscreen && root.isBarActive
    }
    
    Osd {
        id: volumeOSD
    }

    // --- YOUR WALLPAPER BACKGROUND ---
    PanelWindow {
        id: wallpaperWindow
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore

        GlobalShortcut {
            name: "updateWallpaper"
            onPressed: wallpaperContainer.refreshWallpaper()
        }

        Item {
            id: wallpaperContainer
            anchors.fill: parent

            property bool useFront: false

            function refreshWallpaper() {
                console.log("QUICKSHELL: Trigger signal received!")
                let newUrl = "file:///home/duarte/.current.wall?t=" + Date.now()
                if (useFront) { backImage.source = newUrl } 
                else { frontImage.source = newUrl }
            }

            function applyColors() {
                let colorCmd = `matugen --source-color-index 0 image "$HOME/.current.wall" -t scheme-content && sh "$HOME/.config/hypr/scripts/colors_mqtt.sh"`;
                Quickshell.execDetached({ command: ["bash", "-c", colorCmd] });
            }

            Image {
                id: backImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false 
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                source: "file:///home/duarte/.current.wall"
                
                onStatusChanged: {
                    if (status === Image.Ready && wallpaperContainer.useFront) {
                        console.log("QUICKSHELL: Back image ready, crossfading...")
                        wallpaperContainer.useFront = false
                        wallpaperContainer.applyColors() 
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
                        id: fadeAnim
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
                        console.log("QUICKSHELL: Front image ready, crossfading...")
                        wallpaperContainer.useFront = true
                        wallpaperContainer.applyColors() 
                    }
                }
            }
        }
    }
}