import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "./notification_utils.js" as NotificationUtils

Item {
    id: root
    property string appName: ""
    property var groupData: null
    
    // Auto-expand if there is only 1 notification
    property bool expanded: groupData.notifications.length === 1

    width: ListView.view.width
    height: backgroundRect.implicitHeight
    
    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

    function resolveImage(imageStr, iconStr) {
        let src = imageStr ? imageStr.toString() : (iconStr ? iconStr.toString() : "");
        if (src === "") return "";
        if (src.startsWith("file://") || src.startsWith("http://") || src.startsWith("https://") || src.startsWith("image://")) return src;
        if (src.startsWith("/")) return "file://" + src;
        return "image://icon/" + src;
    }

    Rectangle {
        id: backgroundRect
        width: parent.width
        implicitHeight: mainCol.implicitHeight + 24
        color: "transparent"
        border.color: Colors.border
        border.width: 1
        radius: 8
        clip: true

        ColumnLayout {
            id: mainCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 12

            // --- GROUP HEADER ROW ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: resolveImage("", groupData.appIcon || (groupData.notifications.length > 0 ? groupData.notifications[0].appIcon : ""))
                    fillMode: Image.PreserveAspectFit
                    visible: groupData.notifications[0].appIcon != ""
                    sourceSize: Qt.size(20, 20)
                }

                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                // Expand Pill Button
                Rectangle {
                    visible: groupData.notifications.length > 1
                    implicitWidth: expandRow.implicitWidth + 16
                    implicitHeight: 24
                    color: expandMouse.containsMouse ? Colors.workspaceactive : "transparent"
                    border.color: Colors.border
                    border.width: 1
                    radius: 12
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    Row {
                        id: expandRow
                        spacing: 4
                        anchors.centerIn: parent
                        Text {
                            text: groupData.notifications.length.toString()
                            color: Colors.text
                            font.bold: true
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.expanded ? "▲" : "▼"
                            color: Colors.text
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: expandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                // Close Group Button
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: closeGroupMouse.containsMouse ? Colors.workspaceactive : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        font.bold: true
                        color: Colors.text
                        opacity: closeGroupMouse.containsMouse ? 1.0 : 0.6
                    }

                    MouseArea {
                        id: closeGroupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let ids = groupData.notifications.map(n => n.id);
                            NotificationManager.discardNotifications(ids);
                        }
                    }
                }
            }

            // --- REPEATER FOR INDIVIDUAL NOTIFICATIONS ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: root.expanded ? groupData.notifications : []
                    
                    delegate: Rectangle {
                        id: groupItemDelegate 
                        property var currentNotif: modelData

                        // 💡 THE FIX: Action parsers properly separated!
                        property var defaultAction: {
                            if (!currentNotif.actions) return null;
                            for (let i = 0; i < currentNotif.actions.length; i++) {
                                let id = currentNotif.actions[i].identifier;
                                if (id === "default" || id === "view") return currentNotif.actions[i];
                            }
                            return null;
                        }

                        property var customActions: {
                            let arr = [];
                            if (!currentNotif.actions) return arr;
                            for (let i = 0; i < currentNotif.actions.length; i++) {
                                let id = currentNotif.actions[i].identifier;
                                if (id !== "default" && id !== "view") arr.push(currentNotif.actions[i]);
                            }
                            return arr;
                        }

                        Layout.fillWidth: true
                        implicitHeight: groupContentCol.implicitHeight + 16
                        color: "transparent"
                        radius: 8

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.workspaceactive
                            opacity: groupMouse.containsMouse ? 0.10 : 0
                            radius: 8
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Colors.border
                            visible: index > 0
                        }

                        MouseArea {
                            id: groupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // 💡 Hyprland Regex Workspace Focus!
                                let appName = groupItemDelegate.currentNotif.appName;
                                if (appName) {
                                    let safeName = appName.replace(/ /g, '.*');
                                    let cmd = `hyprctl dispatch focuswindow "class:(?i).*${safeName}.*" || hyprctl dispatch focuswindow "title:(?i).*${safeName}.*"`;
                                    Quickshell.execDetached({ command: ["bash", "-c", cmd] });
                                }

                                if (groupItemDelegate.defaultAction) {
                                    NotificationManager.attemptInvokeAction(groupItemDelegate.currentNotif.id, groupItemDelegate.defaultAction.identifier);
                                } else {
                                    NotificationManager.attemptInvokeAction(groupItemDelegate.currentNotif.id, "default");
                                }
                            }
                        }

                        ColumnLayout {
                            id: groupContentCol
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 12
                                Layout.topMargin: index > 0 ? 6 : 0

                                // 💡 THE FIX: Uses App Icon as fallback so it doesn't collapse!
                                Rectangle {
                                    property string imgSrc: resolveImage(groupItemDelegate.currentNotif.cachedImage || groupItemDelegate.currentNotif.image, groupItemDelegate.currentNotif.cachedAppIcon || groupItemDelegate.currentNotif.appIcon)
                                    visible: imgSrc !== ""
                                    Layout.preferredWidth: visible ? 48 : 0
                                    Layout.preferredHeight: visible ? 48 : 0
                                    Layout.alignment: Qt.AlignTop
                                    color: "transparent"
                                    radius: 8
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: parent.imgSrc
                                        fillMode: Image.PreserveAspectCrop 
                                        sourceSize: Qt.size(128, 128)
                                        asynchronous: true
                                        onStatusChanged: if (status === Image.Error) parent.visible = false
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
                                            font.pixelSize: 14
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: NotificationUtils.getFriendlyNotifTimeString(groupItemDelegate.currentNotif.time)
                                            color: Colors.text
                                            font.pixelSize: 11
                                            opacity: 0.5
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            radius: 4
                                            color: closeIndMouse.containsMouse ? Colors.workspaceactive : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                        
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Colors.text
                                                opacity: closeIndMouse.containsMouse ? 1.0 : 0.4
                                            }
                        
                                            MouseArea {
                                                id: closeIndMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotificationManager.discardNotification(groupItemDelegate.currentNotif.id)
                                            }
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

                            // --- INLINE REPLY ---
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                visible: groupItemDelegate.currentNotif.notification && groupItemDelegate.currentNotif.notification.hasInlineReply
                                color: "transparent"
                                border.color: Colors.border
                                border.width: 1
                                radius: 6

                                TextInput {
                                    id: replyInput
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Colors.text
                                    font.pixelSize: 12
                                    clip: true
                                    
                                    Text {
                                        anchors.fill: parent
                                        text: groupItemDelegate.currentNotif.notification ? (groupItemDelegate.currentNotif.notification.inlineReplyPlaceholder || "Reply...") : "Reply..."
                                        color: Colors.text
                                        opacity: 0.5
                                        font.pixelSize: 12
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !replyInput.text && !replyInput.activeFocus
                                    }

                                    onAccepted: {
                                        if (text.trim() !== "") {
                                            if (groupItemDelegate.currentNotif.notification.reply) {
                                                groupItemDelegate.currentNotif.notification.reply(text);
                                            }
                                            NotificationManager.discardNotification(groupItemDelegate.currentNotif.id);
                                        }
                                    }
                                }
                            }

                            // --- ACTION BUTTONS ---
                            // 💡 THE FIX: Safely reads from customActions!
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: groupItemDelegate.customActions.length > 0

                                Repeater {
                                    model: groupItemDelegate.customActions

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        color: actionMouse.containsMouse ? Colors.workspaceactive : "transparent"
                                        border.color: Colors.border
                                        border.width: 1
                                        radius: 6
                                        Behavior on color { ColorAnimation { duration: 100 } }

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