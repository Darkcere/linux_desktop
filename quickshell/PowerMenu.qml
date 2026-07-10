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
            focusCatcher.forceActiveFocus();
        }
    }

    // Your bash options translated to QML data
    ListModel {
        id: powerModel
        ListElement { name: "Suspend System"; iconStr: ""; cmd: "systemctl suspend" }
        ListElement { name: "Power Off System"; iconStr: ""; cmd: "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff'" }
        ListElement { name: "Reboot System"; iconStr: ""; cmd: "hyprshutdown -t 'Restarting...' --post-cmd 'systemctl reboot'" }
        ListElement { name: "Lock Session"; iconStr: ""; cmd: "loginctl lock-session" }
        ListElement { name: "Log Out"; iconStr: ""; cmd: "hyprshutdown -t 'Logging out...'" }
    }

    function executeSelected(index) {
        if (index >= 0 && index < powerModel.count) {
            let bashCmd = powerModel.get(index).cmd;
            console.debug("PowerMenu executing: " + bashCmd);
            Quickshell.execDetached({ command: ["bash", "-c", bashCmd] });
            powerWindow.closeRequested();
        }
    }

    // Invisible item to handle keyboard navigation (Up, Down, Enter, Esc)
    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: (event) => { event.accepted = true; powerWindow.closeRequested(); }
        Keys.onDownPressed: (event) => {
            event.accepted = true;
            powerWindow.selectedIndex = Math.min(powerWindow.selectedIndex + 1, powerModel.count - 1);
        }
        Keys.onUpPressed: (event) => {
            event.accepted = true;
            powerWindow.selectedIndex = Math.max(powerWindow.selectedIndex - 1, 0);
        }
        Keys.onReturnPressed: (event) => {
            event.accepted = true;
            powerWindow.executeSelected(powerWindow.selectedIndex);
        }
    }

    // The visual list
    Column {
        anchors.centerIn: parent
        width: parent.width - 40 // Leave 20px margin on sides
        spacing: 10

        Repeater {
            model: powerModel
            
            delegate: Rectangle {
                width: parent.width
                height: 55
                radius: 8
                
                // Change color if hovered or selected with keyboard
                color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.workspaceactive : Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1)
                border.color: Colors.border
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15
                    
                    Text {
                        text: model.iconStr
                        font.pixelSize: 20
                        color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.background : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: model.name
                        font.pixelSize: 16
                        font.bold: true
                        color: (powerMouseArea.containsMouse || powerWindow.selectedIndex === index) ? Colors.background : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: powerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: powerWindow.executeSelected(index)
                    onEntered: powerWindow.selectedIndex = index
                }
            }
        }
    }
}