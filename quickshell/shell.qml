import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import QtCore
import Quickshell.Services.Polkit
ShellRoot {
    id: root
    PolkitAgent {
        id: globalPolkitAgent

        onIsActiveChanged: {
            if (isActive && dropdownLoader.item) {
                dropdownLoader.item.openPolkit()
            } else if (!isActive && dropdownLoader.item) {
                dropdownLoader.item.closePolkit()
            }
        }
    }
    property var lockedScreen: null
    Connections {
        target: globalPolkitAgent
        function onIsActiveChanged() {
            if (globalPolkitAgent && globalPolkitAgent.isActive) {
                root.lockedScreen = root.activeScreen;
            } else {
                root.lockedScreen = null;
            }
        }
    }
    property var _initNightLight: NightLightService
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") {
                Hyprland.refreshToplevels();
            }
        }
    }
    
    property bool isScreenLocked: false

    Timer {
        interval: 250
        running: !root.isScreenLocked
        repeat: true
        onTriggered: lockCheckProc.running = true
    }

    Process {
        id: lockCheckProc
        command: ["sh", "-c", "[ -f /tmp/qs_locked ] && rm /tmp/qs_locked && echo LOCK"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "LOCK") root.isScreenLocked = true;
            }
        }
    }
    
    property bool realFullscreen: {
        let workspaceHasFs = Hyprland.focusedWorkspace?.hasFullscreen ?? false;
        if (!workspaceHasFs) return false;

        let active = Hyprland.activeToplevel;
        return active?.lastIpcObject?.fullscreen === 2;
    }
    
    property bool isGameMode: false

    onIsGameModeChanged: {
        NotificationManager.silent = isGameMode;
        if (isGameMode) {
            if (dropdownLoader.item) dropdownLoader.item.closeRequested();
            gc(); 
        }
    }

    IpcHandler {
        target: "gamemode"
        function set(state: bool): void {
            root.isGameMode = state;
        }
    }
    
    property var activeScreen: {
        // Freeze screen tracking if Polkit is currently open
        if (root.lockedScreen) return root.lockedScreen;

        let focusName = Hyprland.focusedMonitor?.name;
        let screen = Quickshell.screens.find(s => s.name === focusName);
        return screen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    property var inactiveScreen: {
        // Derive inactive screen relative to current activeScreen rather than raw focus
        let activeName = root.activeScreen?.name;
        let screen = Quickshell.screens.find(s => s.name !== activeName);
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
    
    property bool isBarActive: SettingsService.enableBar
    
    GlobalShortcut { name: "toggleDashboard"; onPressed: dropdownLoader.item?.toggleDashboard() }
    GlobalShortcut { name: "toggleTools"; onPressed: dropdownLoader.item?.toggleTools() }
    GlobalShortcut { name: "toggleSettings"; onPressed: dropdownLoader.item?.toggleSettings() }
    GlobalShortcut { name: "togglePowerMenu"; onPressed: dropdownLoader.item?.togglePowerMenu() }
    GlobalShortcut { name: "toggleClipboard"; onPressed: dropdownLoader.item?.toggleClipboard() }
    GlobalShortcut { name: "toggleLauncher"; onPressed: dropdownLoader.item?.toggleApps() }
    GlobalShortcut { name: "toggleWallpaperPicker"; onPressed: dropdownLoader.item?.openWallpaperPicker() }
    GlobalShortcut { name: "toggleAudioMenu"; onPressed: dropdownLoader.item?.toggleAudio() }
    GlobalShortcut { name: "toggleNotifications"; onPressed: dropdownLoader.item?.toggleNotifications() }
    GlobalShortcut { name: "toggleBar"; onPressed: SettingsService.enableBar = !SettingsService.enableBar }
    
    IpcHandler {
        target: "wallpaper"
        function update(): void {
            root.applySystemColors();
            root.wallpaperToken = Date.now().toString();
        }
    }
    
    Loader {
        id: lockScreenLoader
        active: root.isScreenLocked
        sourceComponent: Component {
            LockScreen {
                isLocked: root.isScreenLocked
                onUnlocked: root.isScreenLocked = false
            }
        }
    }
    
    
    // Main Bar (Only on the actively focused screen)
    Variants {
        model: (root.isBarActive && !root.realFullscreen && root.activeScreen) ? [root.activeScreen] : []
        
        delegate: Component {
            Bar {
                screen: modelData
                menuHandler: dropdownLoader.item 
                isDropdownOpen: dropdownLoader.item?.isOpen ?? false
                dropdownWidth: dropdownLoader.item?.currentDropWidth ?? 0
                onToggleLauncherRequested: dropdownLoader.item?.toggleApps()
                onToggleDashboardRequested: dropdownLoader.item?.toggleDashboard()
                onTogglePowerRequested: dropdownLoader.item?.togglePowerMenu()
                isGameMode: root.isGameMode
            }
        }
    }
    // Dynamic Island Notch with custom MediaPlayer component
    PanelWindow {
        // 💡 Target the specific unfocused screen object, not the whole array
        screen: root.inactiveScreen
        margins{
            bottom: 3;
        }
        // Only show if the bar is active and we actually HAVE an inactive screen 
        // (meaning you have at least 2 monitors connected).
        visible: SettingsService.enableInactiveBar && root.inactiveScreen && (root.inactiveScreen.name !== Hyprland.focusedMonitor?.name)
        
        anchors { top: true; left: false; right: false; bottom: false } 
        WlrLayershell.layer: WlrLayer.Top
        
        width: notchContainer.width
        height: notchContainer.height
        color: "transparent"

        Item {
            id: notchContainer
            
            property bool hasMedia: mediaLoader.status === Loader.Ready && mediaLoader.item && mediaLoader.item.visible
            
            width: hasMedia ? userClock.width + mediaLoader.width + 32 : userClock.width + 32
            height: Math.max(32, userClock.height + 12, userClock.implicitHeight + 12)
            clip: true 
            
            Behavior on width { NumberAnimation { duration: 50; easing.type: Easing.OutExpo } }

            Rectangle {
                width: parent.width
                height: parent.height + radius
                y: -radius 
                
                color: Colors.background
                radius: 12
            }
            

             Row{   
                anchors.centerIn: parent
                spacing: 6
                Clock {
                    id: userClock
                    anchors.verticalCenter: parent.verticalCenter
                    showSeconds: !notchContainer.hasMedia
                }
                
                Loader {
                    id: mediaLoader
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.realFullscreen && !root.isGameMode
                    // 🚨 If you want the Media Player to ALSO stay visible during fullscreen, 
                    // completely delete this "active" line below. 
                    // Leaving it here means it shrinks to just the clock during fullscreen.
                    active: root.realFullscreen && !root.isGameMode
                    
                    sourceComponent: Component {
                        Mediaplayer {
                            // internal Mediaplayer component
                        }
                    }
                }
             }
        }
    }
    Loader {
        id: popupsLoader
        property var trackedScreen: root.activeScreen
        
        Timer {
            id: popupsDebounce
            interval: 150
            onTriggered: {
                if (popupsLoader.trackedScreen !== null) {
                    popupsLoader.active = true;
                }
            }
        }

        onTrackedScreenChanged: {
            active = false; 
            popupsDebounce.restart(); 
        }

        sourceComponent: Component {
            NotificationPopup {
                targetScreen: (!root.realFullscreen) ? root.activeScreen : root.inactiveScreen
                isBarVisible: !root.realFullscreen && root.isBarActive && !dropdownLoader.item?.isOpen
                dropdownOffset: root.isRightMenuOpen ? ((dropdownLoader.item?.currentDropHeight ?? 0) + 10) : 0
            }
        }
    }
    
    Loader {
        id: dropdownLoader
        property var trackedScreen: root.activeScreen
        
        Timer {
            id: dropdownDebounce
            interval: 150
            onTriggered: {
                if (dropdownLoader.trackedScreen !== null) {
                    dropdownLoader.active = true;
                }
            }
        }

        onTrackedScreenChanged: {
            active = false;
            dropdownDebounce.restart();
        }

        sourceComponent: Component {
            DropdownWindow {
                screen: dropdownLoader.trackedScreen
                isBarVisible: !root.realFullscreen && root.isBarActive
                isGameMode: root.isGameMode
            }
        }
    }
    
    Variants {
        model: SettingsService.enableOsd && root.activeScreen ? [root.activeScreen] : []
        delegate: Component {
            Osd {
                screen: modelData
            }
        }
    }
 
    Instantiator {
        id: wallpaperInstantiator
        model: SettingsService.enableWallpaper && !root.isGameMode ? Quickshell.screens : []
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