import Quickshell
import QtQuick
import QtCore

Item {
    id: powerWindow
    
    property bool isOpen: false
    signal closeRequested()

    property int selectedIndex: 0

    // Reset selection and grab keyboard focus when opened
    onIsOpenChanged: {
        if (isOpen) {
            selectedIndex = 0;
            powerWindow.forceActiveFocus();
        }
    }

    // 🚀 OPTIMIZATION 1: Abstracted commands into 'action' keywords. 
    // This allows the execution logic to determine the init system dynamically.
    readonly property var powerModel: [
        { name: "Suspend System", iconStr: "", action: "suspend" }, 
        { name: "Power Off System", iconStr: "", action: "poweroff" },
        { name: "Reboot System", iconStr: "", action: "reboot" },
        { name: "Lock Session", iconStr: "", action: "lock" },
        { name: "Log Out", iconStr: "", action: "logout" }
    ]

    function executeSelected(index) {
        if (index >= 0 && index < powerModel.length) {
            let action = powerModel[index].action;

            let bashCmd = "case \"" + action + "\" in\n" +
                          "  \"suspend\") loginctl suspend ;;\n" +
                          "  \"poweroff\") hyprshutdown -t 'Shutting down...' --post-cmd 'loginctl poweroff' ;;\n" +
                          "  \"reboot\") hyprshutdown -t 'Restarting...' --post-cmd 'loginctl reboot' ;;\n" +
                          "  \"lock\") touch /tmp/qs_locked ;;\n" +
                          "  \"logout\") hyprshutdown -t 'Logging out...' ;;\n" +
                          "esac";

            console.debug("PowerMenu executing action: " + action);
            Quickshell.execDetached({ command: ["bash", "-c", bashCmd] });
            powerWindow.closeRequested();
        }
    }

    // 🚀 OPTIMIZATION 2: Removed the redundant invisible focusCatcher item.
    focus: true
    Keys.onEscapePressed: (event) => { event.accepted = true; powerWindow.closeRequested(); }
    Keys.onDownPressed: (event) => {
        event.accepted = true;
        powerWindow.selectedIndex = Math.min(powerWindow.selectedIndex + 1, powerModel.length - 1);
    }
    Keys.onUpPressed: (event) => {
        event.accepted = true;
        powerWindow.selectedIndex = Math.max(powerWindow.selectedIndex - 1, 0);
    }
    Keys.onReturnPressed: (event) => {
        event.accepted = true;
        powerWindow.executeSelected(powerWindow.selectedIndex);
    }

    // The visual list
    Column {
        anchors.centerIn: parent
        width: parent.width - 40 
        spacing: 10

        Repeater {
            model: powerWindow.powerModel
            
            delegate: Rectangle {
                width: parent.width
                height: 55
                radius: 8
                
                // Change color if hovered or selected with keyboard
                color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.workspaceactive : Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1)
                border.color: Colors.border
                border.width: 1
                
                // 🚀 UI POLISH: Smooth crossfades for the background
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15
                    
                    Text {
                        // When using a JS array, we reference data via 'modelData'
                        text: modelData.iconStr
                        font.pixelSize: 20
                        color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.background : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // 🚀 UI POLISH: Smooth crossfades for the text
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    Text {
                        text: modelData.name
                        font.pixelSize: 16
                        font.bold: true
                        color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.background : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: powerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: powerWindow.executeSelected(index)
                }
            }
        }
    }
}