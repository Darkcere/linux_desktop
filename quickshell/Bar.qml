import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
    id: mainBarWindow 
    WlrLayershell.layer: WlrLayer.Top
    
    property QtObject globalTrayMenu
    property bool isDropdownOpen: false
    property int dropdownWidth: 600
    
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
        anchors.centerIn: parent
        implicitHeight: parent.height
        
        // Dynamically match the width of whichever dropdown is open
        width: mainBarWindow.isDropdownOpen ? mainBarWindow.dropdownWidth : mainBarWindow.width
        
        // 🚀 THE COMPLEMENT FIX: Match the dropdown's 12px radius so the outer corners align perfectly!
        radius: mainBarWindow.isDropdownOpen ? 12 : 5
        
        color: Colors.background
        border.color: Colors.border
        border.width: 2
        clip: true 

        // Smooth animations for the sliding morph effect
        Behavior on width { 
            NumberAnimation { duration: 300; easing.type: Easing.OutQuart } 
        }
        Behavior on radius { 
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart } 
        }

        // --- 🚀 THE SQUARING OFF TRICK ---
        // This covers the bottom curved corners when the bar is open.
        // It forces the bottom to be a perfectly flat line so it seamlessly merges with the dropdown.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12 // Exactly matches the radius to hide the curve
            color: Colors.background
            opacity: mainBarWindow.isDropdownOpen ? 1 : 0
            
            // Draw straight borders straight down the sides to replace the curved ones
            Rectangle { anchors.left: parent.left; width: 2; height: parent.height; color: Colors.border }
            Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Colors.border }
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Item {
            id: innerContent
            // 🚀 VISIBILITY FIX: Lock the content wrapper to the full screen width.
            // This ensures your clock and modules stay perfectly centered and visible,
            // and the sides of the bar look like they are sliding inward to frame them!
            width: mainBarWindow.width
            implicitHeight: mainBarWindow.height
            anchors.centerIn: parent

            Item {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 

                    Text {
                        text: "󰣇"
                        color: Colors.text
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mainBarWindow.toggleLauncherRequested()
                        }
                    }
                    
                    Loader { 
                        active: true 
                        sourceComponent: workspacesComp 
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5 
                    Loader { active: true; sourceComponent: clockComp; anchors.verticalCenter: parent.verticalCenter }
                    Loader { active: true; sourceComponent: mediaPlayerComp; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    
                    Loader { 
                        active: true
                        sourceComponent: audioComp 
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                    Loader { 
                        active: true
                        sourceComponent: trayComp 
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                }
            }
        }
    }

    Component { id: workspacesComp; Workspaces {} }
    Component { id: clockComp; Clock { z: -1 } }
    Component { id: mediaPlayerComp; Mediaplayer { z: 10 } }
    Component { id: audioComp; AudioModule {} }
    Component { id: trayComp; Tray { menuHandler: mainBarWindow.globalTrayMenu } }
}