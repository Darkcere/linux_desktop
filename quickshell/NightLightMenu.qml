import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    color: "transparent"
    border.color: Colors.border
    border.width: 2
    radius: 20

    signal closeRequested()

    Timer {
        id: scrollTimer
        interval: 250
        repeat: false
        onTriggered: NightLightService.applyNightLight(true)
    }

    function applyNightLight() {
        let temp = Math.round(nlSettings.temperature);
        // 💡 Only applies the new temp visually if hyprsunset is currently running
        let cmd = "if pgrep -x hyprsunset >/dev/null; then pkill -x hyprsunset || true; sleep 0.1; nohup hyprsunset -t " + temp + " >/dev/null 2>&1 & disown; fi";
        Quickshell.execDetached({ command: ["bash", "-c", cmd] });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: ""
                color: Colors.text
                font.pixelSize: 14
                
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Night Light"
                color: Colors.text
                font.pixelSize: 16
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
            }
            
            Item { Layout.preferredWidth: 14 } 
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.border
            opacity: 0.5
        }

        // Intensity Slider
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Intensity"; color: Colors.text; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(tempSlider.value) + "K"; color: Colors.text; opacity: 0.7; font.pixelSize: 12 }
            }

            Slider {
                id: tempSlider
                Layout.fillWidth: true
                from: 2500 
                to: 6500   
                stepSize: 100
                
                // 💡 THE FIX: Set the initial value directly so it loads 
                // BEFORE onValueChanged has a chance to trigger
                value: NightLightService.temperature

                onValueChanged: {
                    // Only update the setting if it actually differs from the slider
                    if (NightLightService.temperature !== Math.round(value)) {
                        NightLightService.temperature = Math.round(value);
                    }
                }
                
                onPressedChanged: {
                    if (!pressed) NightLightService.applyNightLight(true);
                }
                
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton 
                    onWheel: (wheel) => {
                        let delta = wheel.angleDelta.y > 0 ? 100 : -100;
                        tempSlider.value = Math.min(6500, Math.max(2500, tempSlider.value + delta));
                        scrollTimer.restart(); 
                        wheel.accepted = true;
                    }
                }
                
                background: Rectangle {
                    x: tempSlider.leftPadding
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    width: tempSlider.availableWidth; height: 4; radius: 2; color: Colors.border 
                    
                    Rectangle {
                        width: tempSlider.visualPosition * parent.width; height: parent.height
                        color: Colors.workspaceactive; radius: 2
                    }
                }
                
                handle: Rectangle {
                    x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    
                    color: Colors.background
                    border.color: Colors.workspaceactive
                    border.width: tempSlider.pressed ? 5 : 2
                    
                    Behavior on border.width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Warm"; color: Colors.text; opacity: 0.5; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "Cool"; color: Colors.text; opacity: 0.5; font.pixelSize: 10 }
            }
        }

        Item { Layout.fillHeight: true }

        // Schedule Settings
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: scheduleLayout.implicitHeight + 20
            color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.3)
            radius: 12

            ColumnLayout {
                id: scheduleLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { 
                        text: "Enable Schedule"
                        color: Colors.text
                        font.pixelSize: 14 
                    }
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 36; height: 20; radius: 10
                        color: NightLightService.scheduleEnabled ? Colors.workspaceactive : Colors.border
                        
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: Colors.background
                            anchors.verticalCenter: parent.verticalCenter
                            x: NightLightService.scheduleEnabled ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NightLightService.scheduleEnabled = !NightLightService.scheduleEnabled
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    opacity: NightLightService.scheduleEnabled ? 1.0 : 0.4
                    enabled: NightLightService.scheduleEnabled
                    
                    Text { text: "From"; color: Colors.text; font.pixelSize: 12; Layout.preferredWidth: 35 }
                    
                    TextField {
                        text: NightLightService.startTime
                        color: Colors.workspaceactive
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        inputMask: "99:99"
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 24
                        
                        background: Rectangle {
                            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.5)
                            radius: 6
                            border.color: parent.activeFocus ? Colors.workspaceactive : "transparent"
                            border.width: 1
                        }
                        
                        onEditingFinished: {
                            if (text.length === 5) NightLightService.startTime = text;
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text { text: "To"; color: Colors.text; font.pixelSize: 12 }
                    
                    TextField {
                        text: NightLightService.endTime
                        color: Colors.workspaceactive
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        inputMask: "99:99"
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 24
                        
                        background: Rectangle {
                            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.5)
                            radius: 6
                            border.color: parent.activeFocus ? Colors.workspaceactive : "transparent"
                            border.width: 1
                        }
                        
                        onEditingFinished: {
                            if (text.length === 5) NightLightService.endTime = text;
                        }
                    }
                }
            }
        }
    }
}