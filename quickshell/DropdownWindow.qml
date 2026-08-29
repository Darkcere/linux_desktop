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

    // --- DYNAMIC MORPHING DIMENSIONS ---
    property int currentDropWidth: {
        if (lastActiveView === "tray") return trayMenuView.item ? trayMenuView.item.implicitWidth : 600; 
        
        const widths = {
            "dashboard": 980,
            "wallpaper": 950,
            "clipboard": 950,
            "powermenu": 400,
            "audio": 450,
            "notifications": 450,
            "polkit": 420,
            "tools": 520
        };
        return widths[lastActiveView] ?? 600;
    }

    property int currentDropHeight: {
        if (lastActiveView === "tray") return trayMenuView.item ? trayMenuView.item.implicitHeight : 450; 
        
        const heights = {
            "dashboard": 380,
            "wallpaper": 500,
            "tools": 570,
            "powermenu": 360,
            "audio": 550,
            "notifications": 550,
            "polkit": 280
        };
        return heights[lastActiveView] ?? 450;
    }
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
    function toggleDashboard() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "dashboard") ? "" : "dashboard" 
    }
    function toggleNotifications() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "notifications") ? "" : "notifications" 
    }
    function toggleTrayMenu(trayItem) {
        if (isPolkitLocked) return;
        if (root.activeView === "tray" && root.currentTrayItem === trayItem) {
            root.closeRequested()
        } else {
            root.currentTrayItem = trayItem
            root.activeView = "tray"
        }
    }
    
    function toggleApps() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "apps") ? "" : "apps" 
    }
    function toggleWallpaperPicker() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "wallpaper") ? "" : "wallpaper" 
    }
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
    function togglePowerMenu() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "powermenu") ? "" : "powermenu" 
    }
    function toggleClipboard() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "clipboard") ? "" : "clipboard" 
    }
    function toggleTools() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "tools") ? "" : "tools" 
    }
    function toggleAudio() { 
        if (isPolkitLocked) return; 
        root.activeView = (root.activeView === "audio") ? "" : "audio" 
    }

    function openPolkit() { root.activeView = "polkit" }
    function closePolkit() { if (root.activeView === "polkit") root.closeRequested() }

    // 💡 THE FIX: Anchor to all 4 sides so the PanelWindow covers the full screen height
    anchors { top: true; bottom: true; left: true; right: true }
    
    exclusiveZone: 0

    color: "transparent"
    visible: isOpen || visualBox.opacity > 0.01 

    WlrLayershell.layer: WlrLayer.Overlay 
    WlrLayershell.namespace: "dropdowns"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // --- FULL-SCREEN BACKGROUND CLICK-CATCHER ---
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
        
        Keys.onPressed: (event) => {
            if (root.activeView === "dashboard" && event.text.length === 1 && event.text.match(/[a-zA-Z0-9\-\+\=\/\*\^\.\(\)]/)) {
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

                Loader {
                    anchors.fill: parent
                    active: root.activeView === "apps" || (root.lastActiveView === "apps" && opacityAnim.running)
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
                    anchors.fill: parent
                    active: root.activeView === "tray" || (root.lastActiveView === "tray" && opacityAnim.running)
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
                    anchors.fill: parent
                    active: root.activeView === "wallpaper" || (root.lastActiveView === "wallpaper" && opacityAnim.running)
                    opacity: root.activeView === "wallpaper" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        WallpaperPicker { isOpen: root.activeView === "wallpaper"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    anchors.fill: parent
                    active: root.activeView === "powermenu" || (root.lastActiveView === "powermenu" && opacityAnim.running)
                    opacity: root.activeView === "powermenu" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        PowerMenu { isOpen: root.activeView === "powermenu"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    anchors.fill: parent
                    active: root.activeView === "clipboard" || (root.lastActiveView === "clipboard" && opacityAnim.running)
                    opacity: root.activeView === "clipboard" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Clipboard { isOpen: root.activeView === "clipboard"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    anchors.fill: parent
                    active: root.activeView === "tools" || (root.lastActiveView === "tools" && opacityAnim.running)
                    opacity: root.activeView === "tools" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        Tools { isOpen: root.activeView === "tools"; onCloseRequested: root.closeRequested() }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root.activeView === "audio" || (root.lastActiveView === "audio" && opacityAnim.running)
                    opacity: root.activeView === "audio" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        AudioMenu { isOpen: root.activeView === "audio"; onCloseRequested: root.closeRequested() }
                    }
                }
                
                Loader {
                    anchors.fill: parent
                    active: root.activeView === "notifications" || (root.lastActiveView === "notifications" && opacityAnim.running)
                    opacity: root.activeView === "notifications" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.morphSpeed / 2 } }
                    sourceComponent: Component {
                        NotificationCenter { isOpen: root.activeView === "notifications"; onCloseRequested: root.closeRequested() }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: true
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
                    anchors.fill: parent
                    active: root.activeView === "dashboard" || (root.lastActiveView === "dashboard" && opacityAnim.running)
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