import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
Row {
    spacing: 3
    property var trigger: Hyprland.focusedWorkspace

    property var extraWorkspaces: (trigger, Hyprland.workspaces.values.filter(w => w.id > 5))
    
    // Always show workspaces 1-5
    Repeater {
        model: 5

        Rectangle {
            id: wsButtonStatic
            required property int index
            
            property int wsId: index + 1

            property var ws:  Hyprland.workspaces.values.find(w => w.id === wsId)

            property bool isEmpty: (ws?.toplevels?.values?.length ?? 0) === 0
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId

            property bool isUrgent: ws?.urgent ?? false
            
            // Priority: Active -> Hovered -> Default
            implicitWidth: isActive ? 30 : (mouseAreaStatic.containsMouse ? 14 : 8)
            implicitHeight: 8
            radius: 6

            // Priority: Urgent -> Empty -> Active -> Default
            color: {
                if (isUrgent) return Colors.workspaceurgent;
                if (isActive && !isEmpty) return Colors.workspaceactive;
                if (isEmpty) return Colors.workspaceempty;
                return Colors.workspace;
            }

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200 } }

                MouseArea {
                    id: mouseAreaStatic
                    anchors.fill: parent
                    hoverEnabled: true // Required to detect hover state
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
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

            implicitWidth: 0 
            implicitHeight: 8
            radius: 6

            color: {
                if (isUrgent) return Colors.workspaceurgent;
                if (isActive && !isEmpty) return Colors.workspaceactive;
                if (isEmpty) return Colors.workspaceempty;
                return Colors.workspace;
            }

            Component.onCompleted: {
                // Update the binding to include the hover state
                implicitWidth = Qt.binding(() => isActive ? 30 : (mouseAreaDynamic.containsMouse ? 14 : 8))
            }

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200 } }

            MouseArea {
                id: mouseAreaDynamic
                anchors.fill: parent
                hoverEnabled: true // Required to detect hover state
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + ws.id)
            }
        }
    }
}