import QtQuick
import Quickshell
import Quickshell.Wayland
import "AudioService.qml"

PanelWindow {
    id: osdWindow
    mask: Region { }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    
    anchors { bottom: true }
    margins { bottom: 120 }
    
    implicitWidth: 240
    implicitHeight: 46
    color: "transparent"

    property bool isMicEvent: displayMicMuted
    property bool timerActive: false
    property bool osdReady: false   // guards against the initial async AudioService connection

    property bool showOSD: displayMicMuted || timerActive
    visible: showOSD

    property real displayVolume: AudioService.sink?.audio?.volume ?? 0
    property bool displayMuted: AudioService.sink?.audio?.muted ?? false
    property bool displayMicMuted: AudioService.source?.audio?.muted ?? false

    readonly property color colorMutedBorder: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.3)

    onDisplayVolumeChanged: {
        if (!osdReady) return
        osdWindow.isMicEvent = false
        osdWindow.triggerOSD()
    }

    onDisplayMutedChanged: {
        if (!osdReady) return
        osdWindow.isMicEvent = false
        osdWindow.triggerOSD()
    }

    onDisplayMicMutedChanged: {
        if (!osdReady) return
        osdWindow.isMicEvent = true
        osdWindow.triggerOSD()
    }

    Component.onCompleted: readyTimer.start()

    Timer {
        id: readyTimer
        interval: 800   // long enough for AudioService.sink/source to attach
        repeat: false
        onTriggered: osdWindow.osdReady = true
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