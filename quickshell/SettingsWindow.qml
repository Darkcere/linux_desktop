import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var targetScreen
    signal closeRequested()

    screen: targetScreen
    visible: true
    width: 620
    height: 760
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins {
        top: 54
        right: 18
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        border.color: Colors.border
        border.width: 2
        radius: 14
        clip: true

        FeatureSettings {
            anchors.fill: parent
            onCloseRequested: root.closeRequested()
        }
    }
}
