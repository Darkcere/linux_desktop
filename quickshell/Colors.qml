pragma Singleton
import QtQuick

QtObject {
    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
    }
    readonly property color background: "#141317"
    readonly property color workspaceurgent: "#ff8678"
    readonly property color workspaceactive: "#7857c8"
    readonly property color workspaceempty: alpha(text, 0.8)
    readonly property color border: "#cfbcff"
    readonly property color workspace: "#5d3ab2"
    readonly property color text: "#cfbcff"
}
