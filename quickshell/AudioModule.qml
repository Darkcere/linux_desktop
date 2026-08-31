import QtQuick
import QtQuick.Controls
import Quickshell

Row {
    id: root
    
    // Using simple spacing on a basic Row is drastically faster than RowLayout
    spacing: 4 
    
    property color activeColor: AudioService.protectionTriggered ? Colors.workspaceurgent : Colors.text
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: mainBarWindow.menuHandler.toggleAudio()
    }
    HoverHandler { id: moduleHover }
    property bool showSlider: moduleHover.hovered || volumeSlider.pressed

    function changeVolume(delta, stepSize) {
        if (!AudioService.sink?.audio) return;
        let currentVol = AudioService.sink.audio.volume;
        // Use the passed stepSize, or default to 0.05
        let step = (delta > 0) ? stepSize : -stepSize; 
        let targetVol = Math.max(0.0, Math.min(1.0, currentVol + step));
        
        // Clean up float math to ensure exact percentages
        targetVol = Math.round(targetVol * 100) / 100;
        
        let safeVol = AudioService.protectedSetVolume(AudioService.sink, targetVol, currentVol);
        AudioService.sink.audio.volume = safeVol;
    }

    // --- 1. Microphone Icon ---
    Text {
        id: micIcon
        anchors.verticalCenter: parent.verticalCenter
        
        // Pushes the entire audio group slightly away from the center modules
        leftPadding: 8 
        
        text: AudioService.source?.audio?.muted ? "󰍭" : "󰍬"
        font.pixelSize: 15
        color: AudioService.source?.audio?.muted ? Colors.border : root.activeColor
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioService.toggleMicMute()
        }
    }
    
    // --- 2. Speaker Icon ---
    Text {
        id: speakerIcon
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (AudioService.sink?.audio?.muted) return "󰝟"
            let vol = AudioService.sink?.audio?.volume ?? 0
            if (vol < 0.3) return "󰕿"
            if (vol < 0.7) return "󰖀"
            return "󰕾"
        }
        font.pixelSize: 15
        color: root.activeColor
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioService.toggleMute()
            onWheel: (wheel) => root.changeVolume(wheel.angleDelta.y, 0.05)
        }
    }

    // --- 3. Volume Percentage ---
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
        color: root.activeColor
        font.pixelSize: 12
        font.weight: 600
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioService.toggleMute()
            onWheel: (wheel) => root.changeVolume(wheel.angleDelta.y, 0.05)
        }
    }

    // --- 5. Custom Quickshell Tooltip ---
    BarToolTip {
        targetItem: root

        active: moduleHover.hovered 
        
        text: {
            if (!active) return ""; // 💡 Wakes up ONLY when hovered!
            
            let sink = AudioService.sink?.audio;
            let source = AudioService.source?.audio;
            
            let sinkText = (sink?.muted ? "󰝟 " : "󰕾 ") + " Out: " + Math.round((sink?.volume ?? 0) * 100) + "%";
            let sourceText = (source?.muted ? "󰍭 " : "󰍬 ") + " In: " + Math.round((source?.volume ?? 0) * 100) + "%";
            
            return sourceText + " | " + sinkText + "\nRight click to open Menu";
        }
        topMargin: 25
    }
}