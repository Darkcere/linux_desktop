import QtQuick
import QtQuick.Layouts
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // --- HEADER ---
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Colors.text
                font.pixelSize: 16
                font.bold: true
            }

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // DND TOGGLE BUTTON
                Rectangle {
                    Layout.preferredWidth: NotificationManager.silent ? 75 : 65
                    Layout.preferredHeight: 26
                    radius: 6
                    // 💡 Uses workspaceactive for hover!
                    color: NotificationManager.silent ? Colors.text : (dndMouseArea.containsMouse ? Colors.workspaceactive : "transparent")
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    RowLayout {
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
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 26
                    radius: 6
                    // 💡 Uses workspaceactive for hover!
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.text
            opacity: 0.1
        }

        // --- EMPTY STATE ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            
            // 💡 Reads from the Grouped List!
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

            // 💡 Delegates to the Group Component
            delegate: NotificationGroup {
                appName: modelData
                groupData: NotificationManager.groupsByAppName[modelData]
            }
        }
    }
}