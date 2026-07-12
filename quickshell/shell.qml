import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

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
    
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup() 
        }
    }
    
    Bar {
        id: mainBarWindow
        menuHandler: dropdownManager 
        
        // Revert to this!
        isDropdownOpen: dropdownManager.isOpen 
        
        dropdownWidth: dropdownManager.currentDropWidth
        onToggleLauncherRequested: dropdownManager.toggleApps()
    }
    
    // --- THE UNIFIED DROPDOWN MANAGER ---
    DropdownWindow {
        id: dropdownManager
        isBarVisible: mainBarWindow.visible && !Hyprland.focusedWorkspace.hasFullscreen
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
                
                // OPTIMIZATION: Limits RAM usage to exactly what the screen needs
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
                
                // OPTIMIZATION: Limits RAM usage
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                
                source: ""
                opacity: wallpaperContainer.useFront ? 1 : 0
                
                Behavior on opacity {
                    NumberAnimation { 
                        id: fadeAnim
                        duration: 500; 
                        easing.type: Easing.InOutQuad 
                    }
                }

                // OPTIMIZATION: Free the hidden image from VRAM once the fade is done
                onOpacityChanged: {
                    if (opacity === 1 && !fadeAnim.running) {
                        backImage.source = "" 
                    } else if (opacity === 0 && !fadeAnim.running) {
                        frontImage.source = ""
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