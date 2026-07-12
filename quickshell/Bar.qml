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
    
    signal toggleLauncherRequested()
    
    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 2
        left: 7
        right: 7
    }

    implicitHeight: 28
    color: "transparent"

    Rectangle {
        id: barVisuals
        implicitHeight: parent.height
        anchors.verticalCenter: parent.verticalCenter
        
        // Morph to the right for both tray AND audio
        anchors.horizontalCenter: (menuHandler && (menuHandler.lastActiveView === "tray" || menuHandler.lastActiveView === "audio")) ? undefined : parent.horizontalCenter
        anchors.right: (menuHandler && (menuHandler.lastActiveView === "tray" || menuHandler.lastActiveView === "audio")) ? parent.right : undefined
        
        width: mainBarWindow.isDropdownOpen ? mainBarWindow.dropdownWidth : mainBarWindow.width
        radius: mainBarWindow.isDropdownOpen ? 12 : 5
        
        color: Colors.background
        border.color: Colors.border
        border.width: 2
        clip: true 

        Behavior on width { 
            NumberAnimation { 
                duration: menuHandler ? menuHandler.morphSpeed : 300 
                easing.type: Easing.OutQuart 
            } 
        }
        Behavior on radius { 
            NumberAnimation { 
                duration: menuHandler ? menuHandler.morphSpeed : 200 
                easing.type: Easing.OutQuart 
            } 
        }

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
            
            Behavior on opacity { 
                NumberAnimation { 
                    duration: menuHandler ? (menuHandler.morphSpeed / 2) : 100 
                } 
            }
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
                    
                    // Hide when tray or audio is open
                    opacity: menuHandler.activeView ? 0 : 1
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
                    
                    // Hide when tray or audio is open
                    opacity: (menuHandler && (menuHandler.activeView === "tray" || menuHandler.activeView === "audio")) ? 0 : 1
                    visible: opacity > 0 
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    
                    Clock { z: -1; anchors.verticalCenter: parent.verticalCenter }
                    Mediaplayer { z: 10; anchors.verticalCenter: parent.verticalCenter }
                }

                // --- RIGHT ROW ---
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    
                    AudioModule {
                        anchors.verticalCenter: parent.verticalCenter
                        // Fade out the audio button when the tray is open (so it doesn't overlap)
                        opacity: (menuHandler && menuHandler.activeView && menuHandler.activeView !== "audio") ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    
                    Tray { 
                        anchors.verticalCenter: parent.verticalCenter
                        // Fade out the tray when the audio menu is open
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