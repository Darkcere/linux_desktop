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
                Hyprland.refreshToplevels(); // Crucial to update lastIpcObject
            }
        }
    }
    
    property bool realFullscreen: {
        // 1. First, check if the workspace even reports fullscreen
        let workspaceHasFs = Hyprland.focusedWorkspace?.hasFullscreen ?? false;
        
        // 2. If no fullscreen at all, return false immediately
        if (!workspaceHasFs) return false;

        // 3. Get the active window's fullscreen state
        let active = Hyprland.activeToplevel;
        let val = active?.lastIpcObject?.fullscreen;

        // 4. Return true ONLY if the value is 2
        // If it is 1, this returns false.
        return val === 2;
    }

    // 💡 NEW: Tracks if a right-side menu is open to push notifications down
    property bool isRightMenuOpen: dropdownManager.isOpen && 
                                   (dropdownManager.activeView === "tray" || 
                                    dropdownManager.activeView === "audio" || 
                                    dropdownManager.activeView === "notifications")

    // ... (Your other shortcuts) ...
    GlobalShortcut {
        name: "toggleTools"
        onPressed: dropdownManager.toggleTools()
    }
    GlobalShortcut {
        name: "togglePowerMenu"
        onPressed: dropdownManager.togglePowerMenu()
    }
    GlobalShortcut {
        name: "toggleClipboard"
        onPressed: dropdownManager.toggleClipboard()
    }
    GlobalShortcut {
        name: "toggleLauncher" 
        onPressed: dropdownManager.toggleApps()
    }
    GlobalShortcut {
        name: "toggleWallpaperPicker"
        onPressed: dropdownManager.openWallpaperPicker() 
    }
    GlobalShortcut {
        name: "toggleAudioMenu"
        onPressed: dropdownManager.toggleAudio() 
    }
    GlobalShortcut {
        name: "toggleNotifications"
        onPressed: dropdownManager.toggleNotifications() 
    }
    
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup() 
        }
    }

    Bar {
        id: mainBarWindow
        menuHandler: dropdownManager 
        isDropdownOpen: dropdownManager.isOpen 
        dropdownWidth: dropdownManager.currentDropWidth
        onToggleLauncherRequested: dropdownManager.toggleApps()
    }

    // 💡 THE FIX: Passes the visibility state AND the dropdown offset!
    NotificationPopup {
        id: popups
        isBarVisible: !root.realFullscreen
        dropdownOffset: root.isRightMenuOpen ? (dropdownManager.currentDropHeight + 10) : 0
    }

    // --- THE UNIFIED DROPDOWN MANAGER ---
    DropdownWindow {
        id: dropdownManager
        isBarVisible: !root.realFullscreen
    }
    
    // remember to not load when shell starts
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
                // The cache buster is still useful to force the property update
                let newUrl = "file:///home/duarte/.current.wall?t=" + Date.now()
                
                if (useFront) {
                    backImage.source = newUrl
                } else {
                    frontImage.source = newUrl
                }
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
                
                // FIX 1: Tell Qt to never cache this local file in memory
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
                
                // FIX 1: Tell Qt to never cache this local file in memory
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
                        
                        // FIX 2: Safely free VRAM when the animation actually stops, 
                        // avoiding the onOpacityChanged race condition.
                        onStopped: {
                            if (frontImage.opacity === 1) {
                                backImage.source = "" 
                            } else if (frontImage.opacity === 0) {
                                frontImage.source = ""
                            }
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