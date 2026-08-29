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

    property var activeScreen: {
        let focusName = Hyprland.focusedMonitor?.name;
        let screen = Quickshell.screens.find(s => s.name === focusName);
        return screen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    // 💡 THE FIX: Track the unfocused screen
    property var inactiveScreen: {
        let focusName = Hyprland.focusedMonitor?.name;
        // Find the first screen that does NOT match the currently focused monitor
        let screen = Quickshell.screens.find(s => s.name !== focusName);
        // If only one monitor is connected, safely fallback to the active screen
        return screen || root.activeScreen;
    }

    property bool isRightMenuOpen: {
        let menu = dropdownLoader.item;
        if (!menu) return false;
        return menu.isOpen && (menu.activeView === "tray" || menu.activeView === "audio" || menu.activeView === "notifications");
    }

    property string wallpaperToken: ""

    function applySystemColors() {
        let colorCmd = `matugen --source-color-index 0 image "$HOME/.current.wall" -t scheme-content && sh "$HOME/.config/hypr/scripts/colors_mqtt.sh"`;
        Quickshell.execDetached({ command: ["bash", "-c", colorCmd] });
    }
    // 💡 THE FIX: Use Quickshell's native PersistentProperties with JSON IO
    PersistentProperties {
        id: shellSettings
        
        // 1. Define your properties (with default values)
        property bool enableBar: true
        property bool enableOsd: true
        
        // Internal flag to prevent saving while we are initially loading
        property bool _isLoaded: false

        // 2. Load from JSON on startup
        Component.onCompleted: {
            try {
                let xhr = new XMLHttpRequest();
                let path = Quickshell.env("HOME") + "/.config/quickshell/shell_settings.json";
                xhr.open("GET", "file://" + path, false);
                xhr.send();
                
                if (xhr.status === 200 || xhr.status === 0) {
                    let data = JSON.parse(xhr.responseText);
                    if (data.enableBar !== undefined) enableBar = data.enableBar;
                    if (data.enableOsd !== undefined) enableOsd = data.enableOsd;
                }
            } catch(e) {
                console.log("No existing config found, starting with defaults.");
            }
            _isLoaded = true; // Safe to save now
        }

        // 3. Trigger a save whenever a property changes
        onEnableBarChanged: if (_isLoaded) save()
        onEnableOsdChanged: if (_isLoaded) save()

        // 4. Save to JSON
        function save() {
            let data = {
                enableBar: enableBar,
                enableOsd: enableOsd
            }
            
            // Convert to string and safely escape it for bash
            let jsonStr = JSON.stringify(data, null, 2).replace(/'/g, "'\\''");
            let cmd = `mkdir -p "$HOME/.config/quickshell" && echo '${jsonStr}' > "$HOME/.config/quickshell/shell_settings.json"`;
            
            Quickshell.execDetached({ command: ["bash", "-c", cmd] });
        }
    }
    property bool isBarActive: shellSettings.enableBar
    
    // Toggle the window with a shortcut
    GlobalShortcut { 
        name: "toggleDashboard"
        onPressed: dropdownLoader.item?.toggleDashboard() 
    }
    
        GlobalShortcut { name: "toggleTools"; onPressed: dropdownLoader.item?.toggleTools() }
    GlobalShortcut { name: "togglePowerMenu"; onPressed: dropdownLoader.item?.togglePowerMenu() }
    GlobalShortcut { name: "toggleClipboard"; onPressed: dropdownLoader.item?.toggleClipboard() }
    GlobalShortcut { name: "toggleLauncher"; onPressed: dropdownLoader.item?.toggleApps() }
    GlobalShortcut { name: "toggleWallpaperPicker"; onPressed: dropdownLoader.item?.openWallpaperPicker() }
    GlobalShortcut { name: "toggleAudioMenu"; onPressed: dropdownLoader.item?.toggleAudio() }
    GlobalShortcut { name: "toggleNotifications"; onPressed: dropdownLoader.item?.toggleNotifications() }
    
    GlobalShortcut { name: "toggleBar"; onPressed: root.isBarActive = !root.isBarActive }
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

    Loader {
        active: root.isBarActive && !root.realFullscreen
        sourceComponent: Component {
            Bar {
                screen: root.activeScreen
                menuHandler: dropdownLoader.item 
                isDropdownOpen: dropdownLoader.item?.isOpen ?? false
                dropdownWidth: dropdownLoader.item?.currentDropWidth ?? 0
                onToggleLauncherRequested: dropdownLoader.item?.toggleApps()
            }
        }
    }
    
    // Add a GlobalShortcut or custom function to trigger the lock manually
    GlobalShortcut { 
        name: "lockSession"
        onPressed: {
            console.log("Lock shortcut intercepted!");
            systemLock.lockSession();
        }
    }
    LazyLoader {
        id: popupsLoader
        loading: true
        NotificationPopup {
            id: popups
            
            // 💡 THE FIX: Feed the unfocused screen to your new targetScreen property
            targetScreen: (!root.realFullscreen) ? root.activeScreen : root.inactiveScreen
            
            isBarVisible: !root.realFullscreen && root.isBarActive && !dropdownLoader.item?.isOpen
            dropdownOffset: root.isRightMenuOpen ? ((dropdownLoader.item?.currentDropHeight ?? 0) + 10) : 0
        }
    }
    
    LazyLoader {
        id: dropdownLoader
        loading: true 
        DropdownWindow {
            screen: root.activeScreen
            isBarVisible: !root.realFullscreen && root.isBarActive
        }
    }
    
    Loader {
        id: osdloader
        // 'active' natively destroys the component from memory when false
        active: shellSettings.enableOsd 
        
        sourceComponent: Component {
            Osd {
                screen: root.activeScreen
            }
        }
    }

    Instantiator {
        id: wallpaperInstantiator
        model: Quickshell.screens
        delegate: LazyLoader {
            loading: !root.realFullscreen
            
            PanelWindow {
                screen: modelData
                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                
                Item {
                    id: wallpaperContainer
                    anchors.fill: parent
                    property bool useFront: false
                    
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
                        source: ""
                        opacity: wallpaperContainer.useFront ? 1 : 0
                        
                        Behavior on opacity {
                            NumberAnimation { 
                                duration: 500; 
                                easing.type: Easing.InOutQuad 
                                onStopped: {
                                    if (frontImage.opacity === 1) { 
                                        backImage.source = ""; 
                                    } else if (frontImage.opacity === 0) { 
                                        frontImage.source = ""; 
                                    }
                                    gc(); 
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
}
