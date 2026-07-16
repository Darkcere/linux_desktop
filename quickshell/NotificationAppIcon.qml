import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Item {
    id: root
    property var appIcon: ""
    property real size: 24

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 6
        clip: true

        Image {
            anchors.fill: parent
            source: root.appIcon || ""
            fillMode: Image.PreserveAspectFit
            visible: source.toString() !== ""
        }
    }
}