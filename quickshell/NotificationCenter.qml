import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    
    property bool isOpen: false
    signal closeRequested()
    
    property bool hasNotifications: NotificationManager.list.length > 0
    
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    Loader {
        anchors.fill: parent
        active: root.isOpen 
        
        // Optional: A quick fade-in so it doesn't feel jarring when it instantiates
        Behavior on opacity { NumberAnimation { duration: 150 } }
        opacity: status === Loader.Ready ? 1 : 0
        
        sourceComponent: Component {
            // 💡 THE GUTS: Everything that used to be loose inside the root Item 
            // now lives inside this Component block!
            Item {
                anchors.fill: parent
                anchors.margins: 14

                // --- HEADER ---
                Item {
                    id: headerArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 30

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        color: Colors.text
                        font.pixelSize: 16
                        font.bold: true
                    }

                    // 💡 FIX: Primitive Row with anchors
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // DND TOGGLE BUTTON
                        Rectangle {
                            // 💡 FIX: Standard width animation, bypassing layout engines entirely!
                            width: NotificationManager.silent ? 75 : 65
                            height: 26
                            radius: 6
                            color: NotificationManager.silent ? Colors.text : (dndMouseArea.containsMouse ? Colors.workspaceactive : "transparent")
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: NotificationManager.silent ? "" : ""
                                    font.pixelSize: 12
                                    color: NotificationManager.silent ? Colors.background : Colors.text
                                }
                                Text {
                                    text: "DND"
                                    color: NotificationManager.silent ? Colors.background : Colors.text
                                    font.pixelSize: 12
                                    font.bold: NotificationManager.silent
                                }
                            }

                            MouseArea {
                                id: dndMouseArea
                                anchors.fill: parent
                                hoverEnabled: true 
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationManager.silent = !NotificationManager.silent
                            }
                        }

                        // CLEAR ALL BUTTON
                        Rectangle {
                            width: 80
                            height: 26
                            radius: 6
                            color: clearMouseArea.containsMouse ? Colors.workspaceactive : "transparent"
                            visible: root.hasNotifications
                            
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Clear All"
                                color: Colors.text
                                font.pixelSize: 12
                                opacity: 0.8
                            }
                            
                            MouseArea {
                                id: clearMouseArea
                                anchors.fill: parent
                                hoverEnabled: true 
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationManager.discardAllNotifications()
                            }
                        }
                    }
                }

                // --- DIVIDER ---
                Rectangle {
                    id: headerDivider
                    anchors.top: headerArea.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Colors.text
                    opacity: 0.1
                }

                // --- EMPTY STATE ---
                Item {
                    // 💡 FIX: Fills the remaining space instantly using top/bottom anchors
                    anchors.top: headerDivider.bottom
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    visible: !root.hasNotifications

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Text {
                            text: NotificationManager.silent ? "" : ""
                            font.pixelSize: 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.7
                            color: Colors.text
                        }
                        
                        Text {
                            text: NotificationManager.silent ? "Do Not Disturb is On" : "No new notifications"
                            color: Colors.text
                            opacity: 0.5
                            font.pixelSize: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // --- NOTIFICATION GROUPS LIST ---
                ListView {
                    id: centerList
                    
                    // 💡 FIX: Fills the remaining space instantly using top/bottom anchors
                    anchors.top: headerDivider.bottom
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    spacing: 12
                    
                    model: NotificationManager.appNameList
                    visible: root.hasNotifications

                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuart }
                            NumberAnimation { property: "scale"; to: 0.8; duration: 250; easing.type: Easing.OutQuart }
                        }
                    }
                    removeDisplaced: Transition {
                        NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutQuart }
                    }

                    delegate: NotificationGroup {
                        appName: modelData
                        groupData: NotificationManager.groupsByAppName[modelData]
                    }
                }
            }
        }
    }
}