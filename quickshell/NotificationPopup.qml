import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: notifWindow
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    
    property var server
    property bool isBarVisible: true
    property int dropdownOffset: 0
    property bool isAnyMenuOpen: false
    property int maxPanelHeight: 1040
    property bool hasNotifications: notifListView.count > 0
    property bool isReady: false
    
    // 💡 NEW: DND State
    property bool dndEnabled: false
    
    // 💡 NEW: Clear popups immediately if DND is turned on
    onDndEnabledChanged: {
        if (dndEnabled) popupModel.clear();
    }
    
    anchors {
        top: true
        right: true
    }
    
    margins {
        top: dropdownOffset
        right: 7     
    }

    Behavior on margins.top { 
        NumberAnimation { duration: 400; easing.type: Easing.OutExpo } 
    }

    color: "transparent"
    implicitWidth: 350
    implicitHeight: visualBox.height 

    Timer {
        interval: 1000
        running: true
        onTriggered: notifWindow.isReady = true
    }

    function removeNotificationByRef(notifRef) {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).notifData === notifRef) {
                popupModel.remove(i);
                break;
            }
        }
    }

    Timer {
        id: trimTimer
        interval: 50 
        repeat: false
        onTriggered: {
            if (notifListView.contentHeight > (notifWindow.maxPanelHeight - 20) && popupModel.count > 1) {
                popupModel.remove(popupModel.count - 1);
                trimTimer.start(); 
            }
        }
    }

    ListModel {
        id: popupModel
    }
    
    Instantiator {
        model: server.trackedNotifications
        delegate: QtObject {
            required property var modelData
            property var notifRef: modelData
        }
        onObjectRemoved: function(index, object) {
            removeNotificationByRef(object.notifRef);
        }
    }
    
    Connections {
        target: server
        function onNotification(notification) {
            // 💡 NEW: Block incoming popups if DND is active
            if (notifWindow.isReady && !notifWindow.dndEnabled) {
                popupModel.insert(0, { "notifData": notification })
                if (popupModel.count > 25) {
                    popupModel.remove(25, popupModel.count - 25)
                }
            }
        }
    }

    // ... (Keep your existing cleanBody, getFriendlyTime, and resolveImage functions exactly as they are) ...
    function cleanBody(bodyText, appName) {
        if (!bodyText) return "";
        if (!appName) return bodyText;
        let lowerApp = appName.toLowerCase();
        let browsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];
        if (browsers.some(name => lowerApp.includes(name))) {
            let lines = bodyText.split('\n\n');
            if (lines.length > 1 && lines[0].startsWith('<a')) { return lines.slice(1).join('\n\n'); }
        }
        return bodyText;
    }

    function getFriendlyTime(timestamp) {
        if (!timestamp) return 'Now';
        const messageTime = new Date(timestamp);
        const now = new Date();
        const diffMs = now.getTime() - messageTime.getTime();
        if (diffMs < 60000) return 'Now';
        if (messageTime.toDateString() === now.toDateString()) {
            const diffMinutes = Math.floor(diffMs / 60000);
            const diffHours = Math.floor(diffMs / 3600000);
            return diffHours > 0 ? `${diffHours}h` : `${diffMinutes}m`;
        }
        return Qt.formatDateTime(messageTime, "MMM dd");
    }

    function resolveImage(imageStr, iconStr) {
        let src = imageStr ? imageStr.toString() : (iconStr ? iconStr.toString() : "");
        if (src === "") return "";
        if (src.startsWith("file://") || src.startsWith("http://") || src.startsWith("https://") || src.startsWith("image://")) return src;
        if (src.startsWith("/")) return "file://" + src;
        return "image://theme/" + src;
    }

    Rectangle {
        id: visualBox
        width: parent.width
        height: hasNotifications ? Math.min(notifListView.contentHeight + 20, maxPanelHeight) : 0
        opacity: hasNotifications ? 1 : 0
        color: Colors.background 
        border.color: Colors.border
        border.width: 2
        radius: 12

        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        Rectangle {
            id: seamlessBridge
            visible: notifWindow.hasNotifications && notifWindow.isBarVisible && !notifWindow.isAnyMenuOpen
            x: 0; y: -5; width: parent.width; height: 17 
            color: Colors.background
            Rectangle { x: 0; y: 5; width: 2; height: 12; color: Colors.border }
            Rectangle { x: parent.width - 2; y: 5; width: 2; height: 12; color: Colors.border }
        }

        Item {
            anchors.fill: parent
            clip: true

            ListView {
                id: notifListView
                anchors.fill: parent
                anchors.margins: 10 
                spacing: 5
                
                interactive: true 
                boundsBehavior: Flickable.StopAtBounds
                model: popupModel 
                
                onContentHeightChanged: {
                    if (contentHeight > (notifWindow.maxPanelHeight - 20) && popupModel.count > 1) {
                        trimTimer.start()
                    }
                }
                
                displaced: Transition {
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y"; duration: 0;}
                        NumberAnimation { property: "opacity"; to: 1.0; duration: 0;  }
                        NumberAnimation { property: "scale"; to: 1.0; duration: 0;  }
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

                    required property var notifData 
                    readonly property var receivedTime: new Date()

                    HoverHandler {
                        id: delegateHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    property real calculatedTimeoutMs: {
                        if (notifData.expireTimeout > 0) return notifData.expireTimeout * 1000;
                        if (notifData.urgency === NotificationUrgency.Critical) return 12000;
                        if (notifData.urgency === NotificationUrgency.Low) return 3000;
                        return 6000;
                    }

                    property var defaultAction: {
                        for (let i = 0; i < notifData.actions.length; i++) {
                            let id = notifData.actions[i].identifier;
                            if (id === "default" || id === "view") return notifData.actions[i];
                        }
                        return null;
                    }

                    property var customActions: {
                        let arr = [];
                        for (let i = 0; i < notifData.actions.length; i++) {
                            let id = notifData.actions[i].identifier;
                            if (id !== "default" && id !== "view") arr.push(notifData.actions[i]);
                        }
                        return arr;
                    }

                    Timer {
                        interval: notifDelegate.calculatedTimeoutMs
                        running: notifDelegate.notifData.expireTimeout !== 0 && !delegateHover.hovered
                        onTriggered: removeNotificationByRef(notifDelegate.notifData)
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
                            onClicked: {
                                notifDelegate.defaultAction ? notifDelegate.defaultAction.invoke() : notifData.dismiss();
                                removeNotificationByRef(notifDelegate.notifData)
                            }
                        }

                        ColumnLayout {
                            id: contentCol
                            anchors {
                                top: parent.top; left: parent.left; right: parent.right
                                margins: 10
                            }
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                
                                Rectangle {
                                    property string imageSource: resolveImage(notifData.image, notifData.appIcon)
                                    visible: imageSource !== ""
                                    Layout.preferredWidth: visible ? 48 : 0  
                                    Layout.preferredHeight: visible ? 48 : 0
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
                                    spacing: 4

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20
                                        
                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: notifData.appName || "System"
                                            color: Colors.text
                                            opacity: 0.6
                                            font.pixelSize: 11
                                            font.capitalization: Font.AllUppercase
                                        }
                                        
                                        Text {
                                            anchors.right: closeBtn.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: getFriendlyTime(notifDelegate.receivedTime)
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
                                                    notifData.dismiss()
                                                    removeNotificationByRef(notifDelegate.notifData)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: notifData.summary || ""
                                        color: Colors.text
                                        font.pixelSize: 14
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: cleanBody(notifData.body, notifData.appName)
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

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                visible: notifData.hasInlineReply
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
                                        text: notifData.inlineReplyPlaceholder || "Reply..."
                                        color: Colors.text
                                        opacity: 0.5
                                        font.pixelSize: 12
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !replyInput.text && !replyInput.activeFocus
                                    }

                                    onAccepted: {
                                        if (text.trim() !== "") {
                                            notifData.sendInlineReply(text)
                                            removeNotificationByRef(notifDelegate.notifData)
                                        }
                                    }
                                }
                            }
                            
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
                                                visible: notifData.hasActionIcons && modelData.identifier !== ""
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
                                                modelData.invoke()
                                                removeNotificationByRef(notifDelegate.notifData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.85
                        implicitHeight: 1
                        color: Colors.text
                        opacity: 0.1
                    }
                }
            }
        }
    }
}