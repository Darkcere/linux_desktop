import QtQuick
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
    height: backgroundRect.height // Tracks the background height for smooth sliding
    
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
        height: mainCol.implicitHeight + 24
        color: "transparent"
        border.color: Colors.border
        border.width: 1
        radius: 8
        clip: true

        // 💡 THE FIX: Swapped ColumnLayout for Column
        Column {
            id: mainCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 12

            // --- GROUP HEADER ROW ---
            // 💡 THE FIX: Swapped RowLayout for anchored primitive Item (Instant render)
            Item {
                width: parent.width
                height: 24

                Image {
                    id: headerIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    source: resolveImage("", groupData.appIcon || (groupData.notifications.length > 0 ? groupData.notifications[0].appIcon : ""))
                    fillMode: Image.PreserveAspectFit
                    visible: groupData.notifications[0].appIcon != ""
                    
                    // 💡 THE FIX: Explicit integer sourceSize
                    sourceSize.width: 20
                    sourceSize.height: 20
                }

                Text {
                    anchors.left: headerIcon.visible ? headerIcon.right : parent.left
                    anchors.leftMargin: headerIcon.visible ? 8 : 0
                    anchors.right: expandPill.visible ? expandPill.left : closeGroupBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appName
                    color: Colors.text
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                // Expand Pill Button
                Rectangle {
                    id: expandPill
                    visible: groupData.notifications.length > 1
                    width: expandRow.width + 16
                    height: 24
                    anchors.right: closeGroupBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    
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
                    id: closeGroupBtn
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
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

            // --- INDIVIDUAL NOTIFICATIONS CONTAINER ---
            Column {
                width: parent.width
                spacing: 8
                
                // 💡 THE FIX: By controlling height and visible, the parent Column 
                // shrinks instantly and triggers the smooth sliding root Behavior!
                height: root.expanded ? implicitHeight : 0
                visible: height > 0
                opacity: root.expanded ? 1 : 0
                clip: true
                
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: groupData.notifications // Always feed data, we hide the parent wrapper
                    
                    delegate: Rectangle {
                        id: groupItemDelegate 
                        property var currentNotif: modelData

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

                        width: parent.width
                        height: groupContentCol.implicitHeight + 16
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

                        // 💡 THE FIX: Swapped ColumnLayout for Column
                        Column {
                            id: groupContentCol
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            spacing: 6

                            // 💡 THE FIX: Swapped RowLayout for Row
                            Row {
                                width: parent.width
                                spacing: 12
                                
                                // Push down slightly if it's not the first item
                                Item { width: 1; height: index > 0 ? 6 : 0; visible: index > 0 }

                                Rectangle {
                                    property string imgSrc: resolveImage(groupItemDelegate.currentNotif.cachedImage || groupItemDelegate.currentNotif.image, groupItemDelegate.currentNotif.cachedAppIcon || groupItemDelegate.currentNotif.appIcon)
                                    visible: imgSrc !== ""
                                    width: visible ? 48 : 0
                                    height: visible ? 48 : 0
                                    color: "transparent"
                                    radius: 8
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: parent.imgSrc
                                        fillMode: Image.PreserveAspectCrop 
                                        
                                        // 💡 THE FIX: Explicit integer sourceSize
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                        
                                        asynchronous: true
                                        onStatusChanged: if (status === Image.Error) parent.visible = false
                                    }
                                }

                                Column {
                                    width: parent.width - (parent.children[1].visible ? 60 : 0) - (index > 0 ? 1 : 0) // Account for the spacer and icon
                                    spacing: 4

                                    Item {
                                        width: parent.width
                                        height: Math.max(summaryText.implicitHeight, 20)
                                        
                                        Text {
                                            id: summaryText
                                            anchors.left: parent.left
                                            anchors.right: timeText.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: groupItemDelegate.currentNotif.summary
                                            color: Colors.text
                                            font.bold: true
                                            font.pixelSize: 14
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            id: timeText
                                            anchors.right: closeIndRect.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: NotificationUtils.getFriendlyNotifTimeString(groupItemDelegate.currentNotif.time)
                                            color: Colors.text
                                            font.pixelSize: 11
                                            opacity: 0.5
                                        }
                                        Rectangle {
                                            id: closeIndRect
                                            width: 20
                                            height: 20
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
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
                                        width: parent.width
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
                                width: parent.width
                                height: 32
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
                            Row {
                                width: parent.width
                                spacing: 8
                                visible: groupItemDelegate.customActions.length > 0

                                Repeater {
                                    model: groupItemDelegate.customActions

                                    delegate: Rectangle {
                                        // 💡 THE FIX: Math instead of Layout.fillWidth
                                        width: (parent.width - (parent.spacing * (groupItemDelegate.customActions.length - 1))) / groupItemDelegate.customActions.length
                                        height: 28
                                        
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