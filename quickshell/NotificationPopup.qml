import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "./notification_utils.js" as NotificationUtils

PanelWindow {
    id: popupWindow
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "popups"

    property bool isBarVisible: true 
    
    // 💡 THE NEW OFFSET TRACKER
    property int dropdownOffset: 0

    anchors { top: true; right: true }
    
    margins { 
        // 💡 Adds the offset so it slides under your open menus!
        top: dropdownOffset 
        right: 7 
    }

    // 💡 Smoothly glides down when a menu opens, and glides back up when it closes
    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

    width: 348
    height: visualBox.height 
    color: "transparent"
    
    property bool hasNotifications: NotificationManager.popupList.length > 0
    visible: hasNotifications

    // --- Image Resolver ---
    function resolveImage(imageStr, iconStr) {
        let src = imageStr ? imageStr.toString() : (iconStr ? iconStr.toString() : "");
        if (src === "") return "";
        if (src.startsWith("file://") || src.startsWith("http://") || src.startsWith("https://") || src.startsWith("image://")) return src;
        if (src.startsWith("/")) return "file://" + src;
        return "image://theme/" + src;
    }

    // --- Safe Timeout Engine ---
    property var popupTracker: ({})
    Timer {
        id: masterTimer
        interval: 200
        running: hasNotifications
        repeat: true
        onTriggered: {
            let now = Date.now();
            let changed = false;
            let currentIds = {};

            NotificationManager.popupList.forEach(notif => {
                currentIds[notif.id] = true;
                if (notif.timer && notif.timer.running) notif.timer.stop();
                if (popupTracker[notif.id] === undefined) popupTracker[notif.id] = { start: now, hovered: false };

                let state = popupTracker[notif.id];
                if (state.hovered) {
                    state.start += 200; 
                    return;
                }

                let timeout = 7000; 
                if (notif.notification) {
                    let urg = notif.notification.urgency;
                    if (urg === NotificationUrgency.Critical) timeout = 0; 
                    else if (urg === NotificationUrgency.Low) timeout = 3000; 
                }

                if (timeout > 0 && (now - state.start) >= timeout) {
                    notif.popup = false;
                    changed = true;
                }
            });

            for (let id in popupTracker) {
                if (!currentIds[id]) delete popupTracker[id];
            }

            if (changed) NotificationManager.triggerListChange();
        }
    }

    // --- MAIN VISUAL BOX ---
    Rectangle {
        id: visualBox
        width: parent.width
        height: hasNotifications ? popupListView.contentHeight + 20 : 0
        opacity: hasNotifications ? 1 : 0
        color: Colors.background 
        border.color: Colors.border
        border.width: 2
        radius: 12
        clip: true

        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        // Seamless Bridge (Only shows if bar is visible AND no dropdown menu is pushing it down!)
        Rectangle {
            id: seamlessBridge
            visible: popupWindow.hasNotifications && popupWindow.isBarVisible && popupWindow.dropdownOffset === 0
            x: 0; y: 0; width: parent.width; height: 12 
            color: Colors.background
            Rectangle { x: 0; y: 0; width: 2; height: 12; color: Colors.border }
            Rectangle { x: parent.width - 2; y: 0; width: 2; height: 12; color: Colors.border }
        }

        ListView {
            id: popupListView
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 5
            
            interactive: false 
            model: NotificationManager.popupList.slice().reverse()
            
            displaced: Transition {
                ParallelAnimation {
                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
                }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { property: "scale"; to: 0.90; duration: 150 }
                }
            }

            delegate: Item {
                id: notifDelegate
                width: ListView.view.width
                height: contentCol.height + 20 

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

                HoverHandler {
                    id: delegateHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (popupWindow.popupTracker[notifDelegate.currentNotif.id]) {
                            popupWindow.popupTracker[notifDelegate.currentNotif.id].hovered = hovered;
                        }
                    }
                }

                Rectangle {
                    id: notifCard
                    anchors.fill: parent
                    color: delegateHover.hovered ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.05) : "transparent"
                    radius: 8
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // 💡 1. Hyprland Regex Workspace Focus
                            let appName = notifDelegate.currentNotif.appName;
                            if (appName) {
                                let safeName = appName.replace(/ /g, '.*');
                                let cmd = `hyprctl dispatch focuswindow "class:(?i).*${safeName}.*" || hyprctl dispatch focuswindow "title:(?i).*${safeName}.*"`;
                                Quickshell.execDetached({ command: ["bash", "-c", cmd] });
                            }

                            // 2. Standard Native Action
                            if (notifDelegate.defaultAction) {
                                NotificationManager.attemptInvokeAction(notifDelegate.currentNotif.id, notifDelegate.defaultAction.identifier);
                            } else {
                                NotificationManager.attemptInvokeAction(notifDelegate.currentNotif.id, "default");
                            }
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors {
                            top: parent.top; left: parent.left; right: parent.right
                            margins: 10
                        }
                        spacing: 10

                        // --- MAIN CONTENT (Left Image, Right Column) ---
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Rectangle {
                                property string imageSource: resolveImage(notifDelegate.currentNotif.cachedImage || notifDelegate.currentNotif.image, notifDelegate.currentNotif.cachedAppIcon || notifDelegate.currentNotif.appIcon)
                                visible: imageSource !== ""
                                Layout.preferredWidth: visible ? 48 : 0  
                                Layout.preferredHeight: visible ? 48 : 0
                                Layout.alignment: Qt.AlignTop
                                radius: 8
                                color: "transparent"
                                clip: true
                                
                                Image {
                                    anchors.fill: parent
                                    source: parent.imageSource
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize: Qt.size(128, 128)
                                    onStatusChanged: if (status === Image.Error) parent.visible = false 
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
                                    
                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: notifDelegate.currentNotif.appName || "System"
                                        color: Colors.text
                                        opacity: 0.6
                                        font.pixelSize: 11
                                        font.capitalization: Font.AllUppercase
                                    }
                                    
                                    Text {
                                        anchors.right: closeBtn.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: NotificationUtils.getFriendlyNotifTimeString(notifDelegate.currentNotif.time)
                                        color: Colors.text
                                        opacity: 0.4
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        id: closeBtn
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20
                                        height: 20
                                        radius: 4
                                        color: closeMouseArea.containsMouse ? Colors.text : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: closeMouseArea.containsMouse ? Colors.background : Colors.text
                                            opacity: closeMouseArea.containsMouse ? 1.0 : 0.4
                                        }

                                        MouseArea {
                                            id: closeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NotificationManager.discardNotification(notifDelegate.currentNotif.id)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: notifDelegate.currentNotif.summary || ""
                                    color: Colors.text
                                    font.pixelSize: 14
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: NotificationUtils.processNotificationBody(notifDelegate.currentNotif.body, notifDelegate.currentNotif.appName)
                                    color: Colors.text
                                    opacity: 0.8
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                    visible: text !== "" 
                                    textFormat: Text.StyledText
                                    maximumLineCount: 6
                                    elide: Text.ElideRight
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.PointingHandCursor 
                                    }
                                }
                            }
                        }

                        // --- INLINE REPLY ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            visible: notifDelegate.currentNotif.notification && notifDelegate.currentNotif.notification.hasInlineReply
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
                                    text: notifDelegate.currentNotif.notification ? (notifDelegate.currentNotif.notification.inlineReplyPlaceholder || "Reply...") : "Reply..."
                                    color: Colors.text
                                    opacity: 0.5
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !replyInput.text && !replyInput.activeFocus
                                }

                                onAccepted: {
                                    if (text.trim() !== "") {
                                        if (notifDelegate.currentNotif.notification.reply) {
                                            notifDelegate.currentNotif.notification.reply(text);
                                        }
                                        NotificationManager.discardNotification(notifDelegate.currentNotif.id);
                                    }
                                }
                            }
                        }
                        
                        // --- CUSTOM ACTIONS ---
                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            visible: notifDelegate.customActions.length > 0 
                            
                            Repeater {
                                id: actionRepeater
                                model: notifDelegate.customActions
                                
                                delegate: Rectangle {
                                    required property var modelData 
                                    
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    color: actionMouseArea.containsMouse ? Colors.text : "transparent"
                                    border.color: Colors.border
                                    border.width: 1
                                    radius: 6
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        spacing: 6
                                        anchors.centerIn: parent

                                        Image {
                                            visible: notifDelegate.currentNotif.notification && notifDelegate.currentNotif.notification.hasActionIcons && modelData.identifier !== ""
                                            source: visible ? resolveImage(modelData.identifier, "") : ""
                                            width: visible ? 14 : 0
                                            height: visible ? 14 : 0
                                            sourceSize: Qt.size(14, 14)
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Text {
                                            text: modelData.text 
                                            color: actionMouseArea.containsMouse ? Colors.background : Colors.text
                                            font.pixelSize: 12
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: actionMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            NotificationManager.attemptInvokeAction(notifDelegate.currentNotif.id, modelData.identifier);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Separator Line
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.85
                        implicitHeight: 1
                        color: Colors.text
                        opacity: 0.1
                        visible: index < popupListView.count - 1 
                    }
                }
            }
        }
    }
}