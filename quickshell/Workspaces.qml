import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Row {
    spacing: 3
    
    // Kept this optimization: avoids destroying/recreating buttons on simple focus changes
    property var extraWorkspaces: Hyprland.workspaces.values.filter(w => w.id > 5)
    
    // Always show workspaces 1-5
    Repeater {
        model: 5

        Rectangle {
            id: wsButtonStatic
            required property int index
            
            property int wsId: index + 1

            // 🚀 THE FIX: Restored `.values.find()` so QML tracks the changes properly!
            property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)

            property bool isEmpty: (ws?.toplevels?.values?.length ?? 0) === 0
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId
            property bool isUrgent: ws?.urgent ?? false
            
            implicitWidth: isActive ? 30 : (mouseAreaStatic.containsMouse ? 14 : 8)
            implicitHeight: 8
            radius: 6

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
                hoverEnabled: true 
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

            // Kept this optimization: smooth inline sizing
            implicitWidth: isActive ? 30 : (mouseAreaDynamic.containsMouse ? 14 : 8)
            implicitHeight: 8
            radius: 6

            color: {
                if (isUrgent) return Colors.workspaceurgent;
                if (isActive && !isEmpty) return Colors.workspaceactive;
                if (isEmpty) return Colors.workspaceempty;
                return Colors.workspace;
            }

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200 } }

            MouseArea {
                id: mouseAreaDynamic
                anchors.fill: parent
                hoverEnabled: true 
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + ws.id)
            }
        }
    }
}