import QtQuick
import Quickshell
import Quickshell.Wayland
import "AudioService.qml" // Assuming it is mapped globally

PanelWindow {
    id: osdWindow
    
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    
    anchors { bottom: true }
    margins { bottom: 120 }
    
    // FIX 1: Fixed Wayland Surface Dimensions!
    // The compositor window never changes size, completely eliminating Wayland stutter.
    implicitWidth: 240
    implicitHeight: 46
    color: "transparent"

    property bool isMicEvent: false 
    property bool timerActive: false

    property bool showOSD: displayMicMuted || timerActive
    visible: showOSD

    // FIX 2: Connect to the new, hot-plug safe AudioService properties
    property real displayVolume: AudioService.sinkVol
    property bool displayMuted: AudioService.sinkMuted
    property bool displayMicMuted: AudioService.micMuted
    
    Connections {
        target: AudioService
        
        function onVolumeChanged(volume, muted, node) {
            osdWindow.isMicEvent = false 
            osdWindow.triggerOSD()
        }
        
        function onMicVolumeChanged(volume, muted, node) {
            osdWindow.isMicEvent = true
            osdWindow.triggerOSD()
        }
    }

    function triggerOSD() {
        timerActive = true
        osdTimer.restart()
    }

    Timer {
        id: osdTimer
        interval: 2000 
        onTriggered: {
            timerActive = false
            if (displayMicMuted) {
                isMicEvent = true
            }
        }
    }

    // --- UI DESIGN ---
    Rectangle {
        id: container
        
        // The container stays perfectly centered inside the invisible Wayland window
        anchors.centerIn: parent 
        
        // The width changes here, natively handled by the QML GPU thread
        width: osdWindow.isMicEvent ? 46 : 240
        height: 46
        
        // Dropped to 150ms with OutExpo for a very premium, snappy pop-out feel
        Behavior on width { 
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo } 
        }

        color: displayMicMuted ? '#86040e0d' : "#040e0d"
        border.color: Colors.border
        border.width: 2
        radius: 6
        clip: true // Crucial for the "reveal" sliding mask effect

        // --- Speaker UI (No RowLayout!) ---
        Item {
            // Lock internal width so items stay perfectly still while the container shrinks
            width: 240 
            height: 46
            anchors.centerIn: parent
            
            opacity: !osdWindow.isMicEvent ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

            Text { 
                id: speakerIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: displayMuted ? "󰝟" : "󰕾"
                color: displayMuted ? Colors.workspaceurgent : Colors.text
                font.pixelSize: 16 
            }
            
            Rectangle {
                anchors.left: speakerIcon.right
                anchors.leftMargin: 12
                anchors.right: percentText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                radius: 4
                color: Colors.background
                
                Rectangle {
                    width: displayMuted ? 0 : (parent.width * displayVolume)
                    height: parent.height
                    radius: 4
                    color: Colors.border
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
            }
            
            Text { 
                id: percentText
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(displayVolume * 100) + "%"
                color: Colors.text
                font.pixelSize: 12
                
                // Fixed width ensures the progress bar has a stable target to anchor to
                width: 35 
                horizontalAlignment: Text.AlignRight 
            }
        }

        // --- Mic UI ---
        Text {
            anchors.centerIn: parent
            opacity: osdWindow.isMicEvent ? 1.0 : 0.0
            visible: opacity > 0
            text: displayMicMuted ? "" : ""
            color: displayMicMuted ? Colors.workspaceurgent : Colors.text
            font.pixelSize: 22
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
        }
    }
}