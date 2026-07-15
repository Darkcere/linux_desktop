import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    
    property bool isOpen: false
    signal closeRequested()
    property var server
    property bool hasNotifications: menuModel.count > 0
    
    // 💡 NEW: DND State and toggle signal
    property bool dndEnabled: false
    signal toggleDndRequested()
    
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    ListModel {
        id: menuModel
    }

    Instantiator {
        id: notifObjects
        model: server.trackedNotifications
        delegate: QtObject { 
            required property var modelData
            property var notifRef: modelData 
        }
        onObjectAdded: function(index, object) {
            menuModel.insert(0, { "modelData": object.notifRef });
        }
        onObjectRemoved: function(index, object) {
            for (let i = 0; i < menuModel.count; i++) {
                if (menuModel.get(i).modelData === object.notifRef) {
                    menuModel.remove(i);
                    break;
                }
            }
        }
    }

    // ... (Keep your cleanBody, getFriendlyTime, and resolveImage functions exactly as they are) ...
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
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

            // 💡 NEW: RowLayout to hold DND and Clear All
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // DND TOGGLE BUTTON
                Rectangle {
                    Layout.preferredWidth: root.dndEnabled ? 75 : 65
                    Layout.preferredHeight: 26
                    radius: 6
                    color: root.dndEnabled ? Colors.text : (dndMouseArea.containsMouse ? Colors.border : "transparent")
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.dndEnabled ? "🔕" : "🔔"
                            font.pixelSize: 12
                        }
                        Text {
                            text: "DND"
                            color: root.dndEnabled ? Colors.background : Colors.text
                            font.pixelSize: 12
                            font.bold: root.dndEnabled
                        }
                    }

                    MouseArea {
                        id: dndMouseArea
                        anchors.fill: parent
                        hoverEnabled: true 
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleDndRequested()
                    }
                }

                // CLEAR ALL BUTTON
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 26
                    radius: 6
                    color: clearMouseArea.containsMouse ? Colors.border : "transparent"
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
                        onClicked: {
                            let pending = [];
                            for (let i = 0; i < notifObjects.count; i++) {
                                let obj = notifObjects.objectAt(i);
                                if (obj && obj.notifRef) pending.push(obj.notifRef);
                            }
                            for (let i = 0; i < pending.length; i++) pending[i].dismiss();
                        }
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
                    text: root.dndEnabled ? "🔕" : "📭"
                    font.pixelSize: 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.7
                }
                
                Text {
                    text: root.dndEnabled ? "Do Not Disturb is On" : "No new notifications"
                    color: Colors.text
                    opacity: 0.5
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // --- NOTIFICATION LIST ---
        ListView {
            id: notifListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.hasNotifications
            
            clip: true
            spacing: 5
            
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            
            model: menuModel
            
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutExpo }
                    NumberAnimation { property: "x"; from: 40; to: 0; duration: 400; easing.type: Easing.OutExpo }
                }
            }
            
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 20; duration: 250; easing.type: Easing.InCubic }
                }
            }
            
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutExpo }
            }

            delegate: Item {
                id: notifDelegate
                width: ListView.view.width
                height: contentCol.height + 20 

                required property var modelData 
                readonly property var receivedTime: new Date()

                HoverHandler { id: delegateHover; cursorShape: Qt.PointingHandCursor }

                property var defaultAction: {
                    for (let i = 0; i < modelData.actions.length; i++) {
                        let id = modelData.actions[i].identifier;
                        if (id === "default" || id === "view") return modelData.actions[i];
                    }
                    return null;
                }

                property var customActions: {
                    let arr = [];
                    for (let i = 0; i < modelData.actions.length; i++) {
                        let id = modelData.actions[i].identifier;
                        if (id !== "default" && id !== "view") arr.push(modelData.actions[i]);
                    }
                    return arr;
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
                        onClicked: notifDelegate.defaultAction ? notifDelegate.defaultAction.invoke() : notifDelegate.modelData.dismiss()
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
                                property string imageSource: resolveImage(notifDelegate.modelData.image, notifDelegate.modelData.appIcon)
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
                                        text: notifDelegate.modelData.appName || "System"
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
                                            onClicked: notifDelegate.modelData.dismiss()
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: notifDelegate.modelData.summary || ""
                                    color: Colors.text
                                    font.pixelSize: 14
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: cleanBody(notifDelegate.modelData.body, notifDelegate.modelData.appName)
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
                            visible: notifDelegate.modelData.hasInlineReply
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
                                    text: notifDelegate.modelData.inlineReplyPlaceholder || "Reply..."
                                    color: Colors.text
                                    opacity: 0.5
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !replyInput.text && !replyInput.activeFocus
                                }

                                onAccepted: {
                                    if (text.trim() !== "") notifDelegate.modelData.sendInlineReply(text)
                                }
                            }
                        }
                        
                        // --- ACTIONS ---
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
                                            visible: notifDelegate.modelData.hasActionIcons && modelData.identifier !== ""
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
                                        onClicked: modelData.invoke()
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