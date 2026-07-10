import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
    id: root
    
    // --- STATE MANAGEMENT ---
    // Can be: "", "apps", "wallpaper", or "clipboard"
    property string activeView: ""
    
    property bool isOpen: activeView !== ""
    property bool isBarVisible: true
    
    signal closeRequested()
    onCloseRequested: root.activeView = ""

    function toggleApps() {
        root.activeView = (root.activeView === "apps") ? "" : "apps"
    }

    function toggleWallpaperPicker() {
        root.activeView = (root.activeView === "wallpaper") ? "" : "wallpaper"
    }
    
    // --- ADD THIS NEW FUNCTION ---
    function openWallpaperPicker() {
        if (root.activeView === "wallpaper") {
            // It is already open! Just force the dice to re-roll.
            wallpaperPickerView.rollRandomWallpaper()
        } else {
            // It is closed. Open it (which triggers the normal onIsOpenChanged logic).
            root.activeView = "wallpaper"
        }
    }
    function togglePowerMenu() {
        root.activeView = (root.activeView === "powermenu") ? "" : "powermenu"
    }
    // NEW FUNCTION
    function toggleClipboard() {
        root.activeView = (root.activeView === "clipboard") ? "" : "clipboard"
    }
    function toggleTools() {
        root.activeView = (root.activeView === "tools") ? "" : "tools"
    }
    // --- DYNAMIC MORPHING DIMENSIONS ---
    property int currentDropWidth: {
        if (activeView === "wallpaper") return 950;
        if (activeView === "clipboard") return 950;
        if (activeView === "powermenu") return 350; // Compact width!
        return 600; // Apps and Clipboard
    }
    property int currentDropHeight: {
        if (activeView === "wallpaper") return 500;
        if (activeView === "tools") return 630;
        if (activeView === "powermenu") return 360; // Just tall enough for the 5 buttons
        return 450;
    }

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
        anchors.horizontalCenter: parent.horizontalCenter
        color: Colors.background 
        border.color: Colors.border
        border.width: 2
        radius: 12
        
        width: root.isOpen ? root.currentDropWidth : 600
        height: root.isOpen ? root.currentDropHeight : 0
        opacity: root.isOpen ? 1 : 0
        
        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuart } }
        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutQuart } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

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

                Apps {
                    anchors.fill: parent
                    isOpen: root.activeView === "apps"
                    opacity: isOpen ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    onCloseRequested: root.closeRequested()
                }

                WallpaperPicker {
                    id: wallpaperPickerView // <-- ADD THIS ID
                    anchors.fill: parent
                    isOpen: root.activeView === "wallpaper"
                    opacity: isOpen ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    onCloseRequested: root.closeRequested()
                }
                // --- LOAD OUR POWER MENU ---
                PowerMenu {
                    anchors.fill: parent
                    isOpen: root.activeView === "powermenu"
                    opacity: isOpen ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    onCloseRequested: root.closeRequested()
                }
                // --- NEW COMPONENT ---
                Clipboard {
                    anchors.fill: parent
                    isOpen: root.activeView === "clipboard"
                    opacity: isOpen ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    onCloseRequested: root.closeRequested()
                }
                Tools {
                    anchors.fill: parent
                    isOpen: root.activeView === "tools"
                    opacity: isOpen ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    onCloseRequested: root.closeRequested()
                }
            }
        }
    }
}