import Quickshell
import Quickshell.Hyprland
import QtQuick

Row {
    spacing: 3
    property bool isGameMode: false
    property var extraWorkspaces: Hyprland.workspaces.values.filter(w => w.id > 5)

    Rectangle {
        id: pillBackground
        width: innerRow.implicitWidth
        height: innerRow.implicitHeight + 15
        radius: 8
        color: "transparent"

        // Place the outer background handler FIRST so it sits beneath the buttons
        MouseArea {
            id: mouseAreaout
            anchors.fill: parent
            hoverEnabled: true
            
            // Catch scroll anywhere on the container background
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) Hyprland.dispatch("hl.dsp.focus({ workspace = '-1' })");
                else if (wheel.angleDelta.y < 0) Hyprland.dispatch("hl.dsp.focus({ workspace = '+1' })");
            }
        }

        Row {
            id: innerRow
            anchors.centerIn: parent
            spacing: 3
            
            // Always show workspaces 1-5
            Repeater {
                model: 5

                Rectangle {
                    id: wsButtonStatic
                    required property int index
                    
                    property int wsId: index + 1
                    property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
                    property bool isEmpty: (ws?.toplevels?.values?.length ?? 0) === 0
                    property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                    property bool isUrgent: ws?.urgent ?? false
                    
                    width: isActive ? 30 : (mouseAreaStatic.containsMouse ? 14 : 8)
                    height: 8
                    radius: 6

                    color: {
                        if (isUrgent) return Colors.workspaceurgent;
                        if (isActive && !isEmpty) return Colors.workspaceactive;
                        if (isEmpty) return Colors.workspaceempty;
                        return Colors.workspace;
                    }
                    
                    Behavior on color {enabled: !isGameMode; ColorAnimation { duration: 300 } }
                    Behavior on width {enabled: !isGameMode; NumberAnimation { duration: 200 } }

                    MouseArea {
                        id: mouseAreaStatic
                        anchors.fill: parent
                        hoverEnabled: true 
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = '" + wsId + "' })")
                    }
                }
            }

            // Show existing workspaces above 5
            Repeater {
                model: extraWorkspaces

                Rectangle {
                    id: wsButtonDynamic
                    required property var modelData

                    property var ws: modelData
                    property bool isActive: Hyprland.focusedWorkspace?.id === ws.id
                    property bool isEmpty: (ws?.toplevels?.values?.length ?? 0) === 0
                    property bool isUrgent: ws ? ws.urgent : false

                    width: isActive ? 30 : (mouseAreaDynamic.containsMouse ? 14 : 8)
                    height: 8
                    radius: 6

                    color: {
                        if (isUrgent) return Colors.workspaceurgent;
                        if (isActive && !isEmpty) return Colors.workspaceactive;
                        if (isEmpty) return Colors.workspaceempty;
                        return Colors.workspace;
                    }

                    Behavior on color {enabled: !isGameMode; ColorAnimation { duration: 300 } }
                    Behavior on width {enabled: !isGameMode; NumberAnimation { duration: 200 } }

                    MouseArea {
                        id: mouseAreaDynamic
                        anchors.fill: parent
                        hoverEnabled: true 
                        cursorShape: Qt.PointingHandCursor
                        // Fix: change wsId to ws.id
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = '" + ws.id + "' })")
                    }
                }
            }
        }
    }
}