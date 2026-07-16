import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
    id: mainBarWindow 
    WlrLayershell.layer: WlrLayer.Top
    property var menuHandler
    property QtObject globalTrayMenu
    property bool isDropdownOpen: false
    property int dropdownWidth: 0
    
    property bool hasNotifications: NotificationManager.list.length > 0 
    property bool hasActivePopup: NotificationManager.popupList.length > 0

    // 💡 NEW: DND property for the Bar
    property bool dndEnabled: false

    signal toggleLauncherRequested()
    
    // --- HELPER PROPERTIES FOR CLEANER LOGIC ---
    property bool isRightAlignedMode: menuHandler && (menuHandler.lastActiveView === "tray" || menuHandler.lastActiveView === "audio" || menuHandler.lastActiveView === "notifications")
    property bool isRightMenuOpen: menuHandler && (menuHandler.activeView === "tray" || menuHandler.activeView === "audio" || menuHandler.activeView === "notifications")

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 5
        left: 7
        right: 7
    }

    implicitHeight: 28
    color: "transparent"

    Rectangle {
        id: barVisuals
        implicitHeight: parent.height
        anchors.verticalCenter: parent.verticalCenter
        
        anchors.horizontalCenter: mainBarWindow.isRightAlignedMode ? undefined : parent.horizontalCenter
        anchors.right: mainBarWindow.isRightAlignedMode ? parent.right : undefined
        
        width: mainBarWindow.isDropdownOpen ? mainBarWindow.dropdownWidth : mainBarWindow.width
        radius: mainBarWindow.isDropdownOpen ? 12 : 5
        
        color: Colors.background
        border.color: Colors.border
        border.width: 2
        clip: true 

        Behavior on width { NumberAnimation { duration: menuHandler ? menuHandler.morphSpeed : 300; easing.type: Easing.OutQuart } }
        Behavior on radius { NumberAnimation { duration: menuHandler ? menuHandler.morphSpeed : 200; easing.type: Easing.OutQuart } }

        // --- 1. DROPDOWN BRIDGE ---
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12 
            color: Colors.background
            
            opacity: mainBarWindow.isDropdownOpen ? 1 : 0 
            visible: opacity > 0
            
            Rectangle { anchors.left: parent.left; width: 2; height: parent.height; color: Colors.border }
            Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Colors.border }
            
            Behavior on opacity { NumberAnimation { duration: menuHandler ? (menuHandler.morphSpeed / 2) : 100 } }
        }

        // --- 2. NOTIFICATION POPUP BRIDGE ---
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            
            width: 348
            height: 12 
            color: Colors.background

            opacity: (!mainBarWindow.isDropdownOpen && mainBarWindow.hasActivePopup) ? 1 : 0
            visible: opacity > 0
            
            // ✅ ADDED anchors.bottom: parent.bottom so it pushes down into the corner!
            Rectangle { 
                anchors.left: parent.left; 
                anchors.bottom: parent.bottom; 
                width: 2; 
                height: parent.height - 10; 
                color: Colors.border 
            }
            Rectangle { 
                anchors.right: parent.right; 
                anchors.bottom: parent.bottom; 
                width: 2; 
                height: parent.height; 
                color: Colors.border 
            }
            
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Item {
            id: innerContent
            x: -barVisuals.x 
            y: 0
            width: mainBarWindow.width
            implicitHeight: mainBarWindow.height

            Item {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                
                // --- LEFT ROW ---
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 
                    
                    opacity: menuHandler && menuHandler.activeView ? 0 : 1
                    visible: opacity > 0 
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    
                    Text {
                        id: archlogo
                        text: "󰣇"
                        color: Colors.text
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        MouseArea {
                            id: archMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mainBarWindow.toggleLauncherRequested()
                        }
                    }
                    
                    Workspaces { anchors.verticalCenter: parent.verticalCenter }
                }

                // --- CENTER ROW ---
                Row {
                    anchors.centerIn: parent
                    spacing: 5 
                    
                    opacity: mainBarWindow.isRightMenuOpen ? 0 : 1
                    visible: opacity > 0 
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    
                    Clock { z: -1; anchors.verticalCenter: parent.verticalCenter }
                    Mediaplayer { z: 10; anchors.verticalCenter: parent.verticalCenter }
                }

                // --- RIGHT ROW ---
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 
                    
                    AudioModule {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: (menuHandler && menuHandler.activeView && menuHandler.activeView !== "audio") ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    Text {
                        // Replaced the outlined bell with the filled bell ()
                        text: NotificationManager.silent ? "🔕" : (hasNotifications ? "" : "")
                        color: hasNotifications ? Colors.text : Colors.text 
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        
                        opacity: (menuHandler && menuHandler.activeView && menuHandler.activeView !== "notifications") ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mainBarWindow.menuHandler.toggleNotifications()
                        }
                    }
                    Tray { 
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: (menuHandler && menuHandler.activeView && menuHandler.activeView !== "tray") ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        menuHandler: mainBarWindow.menuHandler
                    }
                }
            }
        }
    }
    
    BarToolTip {
        targetItem: archlogo
        active: archMouseArea.containsMouse
        text: "Open Launcher"
        topMargin: 20
        leftMargin: 42
    }
}