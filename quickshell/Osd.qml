import QtQuick
import Quickshell
import Quickshell.Wayland
import "AudioService.qml"

PanelWindow {
    id: osdWindow
    
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    
    anchors { bottom: true }
    margins { bottom: 120 }
    
    implicitWidth: 240
    implicitHeight: 46
    color: "transparent"

    property bool isMicEvent: displayMicMuted
    property bool timerActive: false

    property bool showOSD: displayMicMuted || timerActive
    visible: showOSD

    property real displayVolume: AudioService.sinkVol
    property bool displayMuted: AudioService.sinkMuted
    property bool displayMicMuted: AudioService.micMuted

    // OPTIMIZATION 1: Cache complex color calculations
    // Evaluates once instead of every time displayMicMuted toggles
    readonly property color colorMutedBorder: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.3)
    readonly property color colorTransparent: Qt.rgba(0, 0, 0, 0)
    
    Connections {
        target: AudioService
        
        // OPTIMIZATION 2: Omit unused arguments (volume, muted, node)
        // Prevents the JS engine from needlessly allocating variables on every signal pulse
        function onVolumeChanged() {
            osdWindow.isMicEvent = false 
            osdWindow.triggerOSD()
        }
        
        function onMicVolumeChanged() {
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
            if (osdWindow.displayMicMuted) {
                osdWindow.isMicEvent = true
            }
        }
    }

    Rectangle {
        id: container
        anchors.centerIn: parent 
        
        width: osdWindow.isMicEvent ? 46 : 240
        height: 46
        
        Behavior on width { 
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo } 
        }

        // Uses cached properties
        color: '#040e0d'
        opacity: displayMicMuted ? 0.8 : 0.9
        border.color: osdWindow.displayMicMuted ? osdWindow.colorMutedBorder : Colors.border
        border.width: 2
        radius: 6
        clip: true 

        // --- Speaker UI ---
        Item {
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
                text: osdWindow.displayMuted ? "󰝟" : "󰕾"
                color: osdWindow.displayMuted ? Colors.workspaceurgent : Colors.text
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
                    // OPTIMIZATION 3: Ensure parent width is resolved via anchors before calculation
                    width: osdWindow.displayMuted ? 0 : (parent.width * osdWindow.displayVolume)
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
                // OPTIMIZATION 4: Kept binding minimal.
                text: Math.round(osdWindow.displayVolume * 100) + "%"
                color: Colors.text
                font.pixelSize: 12
                width: 35 
                horizontalAlignment: Text.AlignRight 
            }
        }

        // --- Mic UI ---
        Text {
            anchors.centerIn: parent
            opacity: osdWindow.isMicEvent ? (osdWindow.displayMicMuted ? 0.7 : 1.0) : 0.0
            visible: opacity > 0
            text: osdWindow.displayMicMuted ? "" : ""
            color: Colors.text
            font.pixelSize: 22
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
        }
    }
}