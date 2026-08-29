import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
    id: root
    // --- STATE MANAGEMENT ---
    property string activeView: ""
    property bool isOpen: activeView !== ""
    property string lastActiveView: ""
    property bool isBarVisible: false
    property var currentTrayItem: null
    property string pendingAppSearch: ""

    // 💡 THE LOCK: True whenever Polkit is actively prompting
    property bool isPolkitLocked: root.activeView === "polkit"

    // ⚡ PRE-COMPILED REGEX (Performance boost for typing detection)
    property var searchRegex: /^[a-zA-Z0-9\-\+\=\/\*\^\.\(\)]$/

    // ⚡ O(1) DYNAMIC MORPHING DIMENSIONS (Massive performance boost over dictionary objects)
    function getDropWidth(view) {
        if (view === "tray") return trayMenuView.item ? trayMenuView.item.implicitWidth : 600; 
        switch(view) {
            case "dashboard": return 980;
            case "wallpaper":
            case "clipboard": return 950;
            case "powermenu": return 400;
            case "audio":
            case "notifications": return 450;
            case "polkit": return 420;
            case "tools": return 520;
            default: return 600;
        }
    }

    function getDropHeight(view) {
        if (view === "tray") return trayMenuView.item ? trayMenuView.item.implicitHeight : 450; 
        switch(view) {
            case "dashboard": return 380;
            case "wallpaper": return 500;
            case "tools": return 570;
            case "powermenu": return 360;
            case "audio":
            case "notifications": return 550;
            case "polkit": return 280;
            default: return 450;
        }
    }

    property int currentDropWidth: getDropWidth(lastActiveView)
    property int currentDropHeight: getDropHeight(lastActiveView)
    property bool isRightAligned: lastActiveView === "tray" || lastActiveView === "audio" || lastActiveView === "notifications"
    property int morphSpeed: 350
    onActiveViewChanged: {
        if (activeView !== "") {
            lastActiveView = activeView
        }
    }
    
    signal closeRequested()
    onCloseRequested: {
        root.activeView = ""
    }

    // --- PROTECTED TOGGLES ---
    function toggleDashboard() { if (!isPolkitLocked) root.activeView = (root.activeView === "dashboard") ? "" : "dashboard" }
    function toggleNotifications() { if (!isPolkitLocked) root.activeView = (root.activeView === "notifications") ? "" : "notifications" }
    function toggleTrayMenu(trayItem) {
        if (isPolkitLocked) return;
        if (root.activeView === "tray" && root.currentTrayItem === trayItem) {
            root.closeRequested()
        } else {
            root.currentTrayItem = trayItem
            root.activeView = "tray"
        }
    }
    
    function toggleApps() { if (!isPolkitLocked) root.activeView = (root.activeView === "apps") ? "" : "apps" }
    function toggleWallpaperPicker() { if (!isPolkitLocked) root.activeView = (root.activeView === "wallpaper") ? "" : "wallpaper" }
    function openWallpaperPicker() {
        if (isPolkitLocked) return;
        if (root.activeView === "wallpaper") {
            if (wallpaperPickerLoader.item) {
                wallpaperPickerLoader.item.rollRandomWallpaper()
            }
        } else {
            root.activeView = "wallpaper"
        }
    }
    function togglePowerMenu() { if (!isPolkitLocked) root.activeView = (root.activeView === "powermenu") ? "" : "powermenu" }
    function toggleClipboard() { if (!isPolkitLocked) root.activeView = (root.activeView === "clipboard") ? "" : "clipboard" }
    function toggleTools() { if (!isPolkitLocked) root.activeView = (root.activeView === "tools") ? "" : "tools" }
    function toggleAudio() { if (!isPolkitLocked) root.activeView = (root.activeView === "audio") ? "" : "audio" }

    function openPolkit() { root.activeView = "polkit" }
    function closePolkit() { if (root.activeView === "polkit") root.closeRequested() }

    // 💡 THE FIX: Anchored to TOP (normal position), with bounded height to prevent Wayland hijacking
    anchors { top: true; left: true; right: true; bottom: true }
    height: isOpen ? root.currentDropHeight : 0
    
    exclusiveZone: 0

    color: "transparent"
    visible: isOpen || visualBox.opacity > 0.01 

    WlrLayershell.layer: WlrLayer.Overlay 
    WlrLayershell.namespace: "dropdowns"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // --- CLICK AND KEY CATCHER ---
    MouseArea { 
        id: bgMouseArea
        anchors.fill: parent
        enabled: root.isOpen
        focus: true
        
        Connections {
            target: root
            function onActiveViewChanged() {
                if (root.activeView === "dashboard") {
                    bgMouseArea.forceActiveFocus()
                }
            }
        }
        
        // Ensure Escape closes the window
        Keys.onEscapePressed: {
            if (!root.isPolkitLocked) {
                root.closeRequested()
            }
        }

        // Dashboard typing detection to switch to Apps launcher
        Keys.onPressed: (event) => {
            if (root.activeView === "dashboard" && event.text.length === 1 && searchRegex.test(event.text)) {
                root.pendingAppSearch = event.text;
                root.activeView = "apps";
                event.accepted = true;
            }
        }

        onClicked: {
            if (!root.isPolkitLocked) {
                root.closeRequested()
            }
        }
    }

    Rectangle {
        id: visualBox
        anchors.top: parent.top
        
        anchors.horizontalCenter: root.isRightAligned ? undefined : parent.horizontalCenter
        anchors.right: root.isRightAligned ? parent.right : undefined
        anchors.rightMargin: root.isRightAligned ? 7 : 0 
        transformOrigin: root.isRightAligned ? Item.TopRight : Item.Top

        color: Colors.background 
        border.color: Colors.border
        border.width: 2
        radius: 12
        
        width: root.isOpen ? root.currentDropWidth : (parent.width - 14)
        height: root.isOpen ? root.currentDropHeight : 0
        opacity: root.isOpen ? 1 : 0
        
        Behavior on width { NumberAnimation { duration: root.morphSpeed; easing.type: Easing.OutQuart } }
        Behavior on height { NumberAnimation { duration: root.morphSpeed; easing.type: Easing.OutQuart } }
        Behavior on opacity { 
            NumberAnimation { 
                id: opacityAnim
                duration: 100 
            } 
        }

        // Stops clicks inside the dropdown card from propagating to the background closer
        MouseArea { anchors.fill: parent } 

        Rectangle {
            id: seamlessBridge
            visible: root.isBarVisible 
            x: 0; y: -5; width: parent.width; height: 17 
            color: Colors.background
            
            Rectangle { anchors.left: parent.left; width: 2; height: parent.height; color: Colors.border }
            Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Colors.border }
        }

        Item {
            id: clipWrapper
            anchors.fill: parent
            clip: true

            Item {
                id: contentContainer
                width: parent.width
                height: root.currentDropHeight 

                // ⚡ LAZY-LOAD & KEEP-ALIVE SYSTEM: Eliminates lag when reopening views
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "apps"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "apps" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Apps { 
                            isOpen: root.activeView === "apps"
                            injectedText: root.pendingAppSearch 
                            onCloseRequested: root.closeRequested() 
                        }
                    }
                }
                
                Loader {
                    id: trayMenuView
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "tray"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "tray" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    sourceComponent: Component {
                        TrayMenu {
                            isOpen: root.activeView === "tray"
                            activeItem: root.currentTrayItem
                            onCloseRequested: root.closeRequested()
                        }
                    }
                }
                
                Loader {
                    id: wallpaperPickerLoader
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "wallpaper"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "wallpaper" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        WallpaperPicker { isOpen: root.activeView === "wallpaper"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "powermenu"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "powermenu" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        PowerMenu { isOpen: root.activeView === "powermenu"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "clipboard"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "clipboard" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Clipboard { isOpen: root.activeView === "clipboard"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "tools"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "tools" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Tools { isOpen: root.activeView === "tools"; onCloseRequested: root.closeRequested() }
                    }
                }

                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "audio"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "audio" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        AudioMenu { isOpen: root.activeView === "audio"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "notifications"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "notifications" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        NotificationCenter { isOpen: root.activeView === "notifications"; onCloseRequested: root.closeRequested() }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: true // Always active to catch auth prompts immediately
                    opacity: root.activeView === "polkit" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        PolkitDialog { 
                            isOpen: root.activeView === "polkit"
                            onOpenRequested: root.openPolkit()
                            onCloseRequested: root.closePolkit()
                        }
                    }
                }
                
                Loader {
                    property bool keepAlive: false
                    active: keepAlive || root.activeView === "dashboard"
                    onActiveChanged: if (active) keepAlive = true
                    
                    anchors.fill: parent
                    opacity: root.activeView === "dashboard" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Dashboard { isOpen: root.activeView === "dashboard"; onCloseRequested: root.closeRequested() }
                    }
                }
            }
        }
    }
}