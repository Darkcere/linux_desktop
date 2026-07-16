import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Item {
    id: root
    property var actions: []
    property var notificationObject: null
    property int urgency: NotificationUrgency.Normal

    Layout.fillWidth: true
    implicitHeight: actions.length > 0 ? 32 : 0
    height: implicitHeight
    clip: true
    visible: actions.length > 0

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: actions

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                hoverEnabled: true

                background: Rectangle {
                    color: parent.hovered ? Colors.border : "transparent"
                    border.color: Colors.border
                    border.width: 1
                    radius: 6
                    
                    // Critical red highlight if needed
                    Rectangle {
                        anchors.fill: parent
                        visible: root.urgency === NotificationUrgency.Critical
                        color: parent.hovered ? "#ff6666" : "#ff5555"
                        radius: 6
                    }
                }

                contentItem: Text {
                    text: modelData.text
                    color: root.urgency === NotificationUrgency.Critical ? Colors.background : Colors.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 12
                }

                onClicked: {
                    if (root.notificationObject) {
                        NotificationManager.attemptInvokeAction(root.notificationObject.id, modelData.identifier);
                    }
                }
            }
        }
    }
}