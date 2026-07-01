import Quickshell
import QtQuick

PanelWindow {
    id: mainBarWindow 
    
    // Allow shell.qml to pass the TrayMenu reference in
    property QtObject globalTrayMenu

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
        id: background
        anchors.fill: parent 

        color: Colors.background
        border.color: Colors.border
        border.width: 2
        radius: 5
        
        Item {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9

            // --- 1. LEFT MODULES ---
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 

                Text {
                    text: "󰣇"
                    color: Colors.text
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Loader {
                    active: true
                    sourceComponent: workspacesComp
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- 2. CENTER MODULES ---
            Row {
                anchors.centerIn: parent
                spacing: 5 

                Loader {
                    active: true
                    sourceComponent: clockComp
                    anchors.verticalCenter: parent.verticalCenter
                }
                Loader {
                    active: true
                    sourceComponent: mediaPlayerComp
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- 3. RIGHT MODULES ---
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

    // --- COMPONENT DEFINITIONS ---
    Component { id: workspacesComp; Workspaces {} }
    Component { id: clockComp; Clock {} }
    Component { id: mediaPlayerComp; Mediaplayer { z: 10 } }
    Component { id: audioComp; AudioModule {} }
    
    // Pass the injected property to the Tray module
    Component { id: trayComp; Tray { menuHandler: mainBarWindow.globalTrayMenu } }
}