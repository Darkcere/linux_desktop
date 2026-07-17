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
    // --- DYNAMIC MORPHING DIMENSIONS ---
    // --- DYNAMIC MORPHING DIMENSIONS ---
    property int currentDropWidth: {
        if (lastActiveView === "tray") return trayMenuView.item ? trayMenuView.item.implicitWidth : 600; 
        
        // Define a fast lookup table
        const widths = {
            "wallpaper": 950,
            "clipboard": 950,
            "powermenu": 350,
            "audio": 450,
            "notifications": 450
        };
        // Return the mapped value, or default to 600
        return widths[lastActiveView] ?? 600;
    }

    property int currentDropHeight: {
        if (lastActiveView === "tray") return trayMenuView.item ? trayMenuView.item.implicitHeight : 450; 
        
        // Define a fast lookup table
        const heights = {
            "wallpaper": 500,
            "tools": 630,
            "powermenu": 360,
            "audio": 550,
            "notifications": 550
        };
        // Return the mapped value, or default to 450
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
    function toggleNotifications() { root.activeView = (root.activeView === "notifications") ? "" : "notifications" }
    function toggleTrayMenu(trayItem) {
        if (root.activeView === "tray" && root.currentTrayItem === trayItem) {
            root.closeRequested()
        } else {
            root.currentTrayItem = trayItem
            root.activeView = "tray"
        }
    }
    
    function toggleApps() { root.activeView = (root.activeView === "apps") ? "" : "apps" }
    function toggleWallpaperPicker() { root.activeView = (root.activeView === "wallpaper") ? "" : "wallpaper" }
    function openWallpaperPicker() {
        if (root.activeView === "wallpaper") {
            if (wallpaperPickerLoader.item) {
                wallpaperPickerLoader.item.rollRandomWallpaper()
            }
        } else {
            root.activeView = "wallpaper"
        }
    }
    function togglePowerMenu() { root.activeView = (root.activeView === "powermenu") ? "" : "powermenu" }
    function toggleClipboard() { root.activeView = (root.activeView === "clipboard") ? "" : "clipboard" }
    function toggleTools() { root.activeView = (root.activeView === "tools") ? "" : "tools" }
    function toggleAudio() { root.activeView = (root.activeView === "audio") ? "" : "audio" }

    

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    visible: isOpen || visualBox.opacity > 0.01 

    WlrLayershell.layer: WlrLayer.Overlay 
    WlrLayershell.namespace: "dropdowns"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { 
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: root.closeRequested() 
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
                        Apps { isOpen: root.activeView === "apps"; onCloseRequested: root.closeRequested() }
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
            }
        }
    }
}