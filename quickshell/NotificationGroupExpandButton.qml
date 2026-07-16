import QtQuick
import QtQuick.Controls

Button {
    id: root
    property int count: 1
    property bool expanded: false

    visible: count > 1
    implicitWidth: contentRow.implicitWidth + 16
    implicitHeight: 24
    hoverEnabled: true

    background: Rectangle {
        color: root.hovered ? Colors.border : "transparent"
        border.color: Colors.border
        border.width: 1
        radius: 12
    }

    contentItem: Row {
        id: contentRow
        spacing: 4
        anchors.centerIn: parent

        Text {
            text: root.count.toString()
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
}