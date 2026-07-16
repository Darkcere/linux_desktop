import QtQuick
import QtQuick.Layouts
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property string appName: ""
    property var groupData: null
    
    property bool expanded: groupData.notifications.length === 1

    width: ListView.view.width
    height: backgroundRect.implicitHeight
    
    Behavior on height { 
        NumberAnimation { duration: 300; easing.type: Easing.OutQuart } 
    }

    Rectangle {
        id: backgroundRect
        width: parent.width
        implicitHeight: mainCol.implicitHeight + 24
        color: "transparent"
        border.color: Colors.border
        border.width: 2
        radius: 12
        clip: true

        ColumnLayout {
            id: mainCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 12

            // --- HEADER ROW (App Name & Expand Button) ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                NotificationAppIcon { 
                    appIcon: groupData.appIcon || (groupData.notifications.length > 0 ? groupData.notifications[0].appIcon : "")
                }

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                NotificationGroupExpandButton {
                    count: groupData.notifications.length
                    expanded: root.expanded
                    onClicked: root.expanded = !root.expanded
                }

                Text {
                    text: "✕"
                    color: Colors.text
                    font.pixelSize: 14
                    opacity: 0.6
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let ids = groupData.notifications.map(n => n.id);
                            NotificationManager.discardNotifications(ids);
                        }
                    }
                }
            }

            // --- GROUPED NOTIFICATIONS LIST ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: root.expanded ? groupData.notifications : []
                    
                    // 💡 THE FIX: Wrapped in a Rectangle to handle hovering/clicks
                    delegate: Rectangle {
                        id: groupItemDelegate 
                        property var currentNotif: modelData

                        Layout.fillWidth: true
                        implicitHeight: groupContentCol.implicitHeight + 16
                        color: "transparent"
                        radius: 8

                        // 💡 THE HOVER ANIMATION BACKGROUND
                        Rectangle {
                            anchors.fill: parent
                            color: Colors.text
                            opacity: groupMouse.containsMouse ? 0.05 : 0
                            radius: 8
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Separator line
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Colors.border
                            visible: index > 0
                        }

                        // 💡 THE DEFAULT ACTION CLICK LISTENER
                        MouseArea {
                            id: groupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NotificationManager.attemptInvokeAction(groupItemDelegate.currentNotif.id, "default");
                            }
                        }

                        ColumnLayout {
                            id: groupContentCol
                            // Using slight margins here indents it nicely under the Header
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            spacing: 6

                            // --- CONTENT ROW (Left Image + Right Texts) ---
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 12
                                Layout.topMargin: index > 0 ? 6 : 0

                                Rectangle {
                                    property string imgSrc: groupItemDelegate.currentNotif.cachedImage || groupItemDelegate.currentNotif.image || ""
                                    
                                    Layout.preferredWidth: 56
                                    Layout.preferredHeight: 56
                                    Layout.alignment: Qt.AlignTop
                                    visible: imgSrc !== ""
                                    color: "transparent"
                                    radius: 8
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: parent.imgSrc
                                        fillMode: Image.PreserveAspectCrop 
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: groupItemDelegate.currentNotif.summary
                                            color: Colors.text
                                            font.bold: true
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: NotificationUtils.getFriendlyNotifTimeString(groupItemDelegate.currentNotif.time)
                                            color: Colors.text
                                            font.pixelSize: 11
                                            opacity: 0.6
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: NotificationUtils.processNotificationBody(groupItemDelegate.currentNotif.body, groupItemDelegate.currentNotif.appName)
                                        color: Colors.text
                                        font.pixelSize: 13
                                        opacity: 0.8
                                        wrapMode: Text.Wrap
                                        visible: text !== ""
                                        maximumLineCount: 4 
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // --- ACTION BUTTONS ---
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: groupItemDelegate.currentNotif.actions && groupItemDelegate.currentNotif.actions.length > 0

                                Repeater {
                                    model: groupItemDelegate.currentNotif.actions

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        color: actionMouse.containsMouse ? Colors.border : "transparent"
                                        border.color: Colors.border
                                        border.width: 1
                                        radius: 6

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: Colors.text
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NotificationManager.attemptInvokeAction(groupItemDelegate.currentNotif.id, modelData.identifier);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}