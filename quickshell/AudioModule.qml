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
    
    // --- 4. The Slider Reveal Mask ---
    Item {
        anchors.verticalCenter: parent.verticalCenter
        
        // Animating a basic item width runs on the fast scene-graph rendering thread!
        width: root.showSlider ? 80 : 0
        height: 14
        clip: true 
        opacity: root.showSlider ? 1.0 : 0.0

        // Adjusted to 400ms: A snppier slide-out feels significantly more premium on a top panel
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

        Slider {
            id: volumeSlider
            width: 80 
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left 
            padding: 0
            from: 0.0
            to: 1.0
            value: AudioService.sink?.audio?.volume ?? 0

            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: volumeSlider.availableWidth
                height: 4
                radius: 2
                color: Colors.border 
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    color: root.activeColor
                    radius: 2
                }
            }

            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                implicitWidth: 7
                implicitHeight: 7
                radius: 5
                color: root.activeColor
            }

            onMoved: {
                if (AudioService.sink?.audio) {
                    let steppedValue = Math.round(value * 100) / 100;
                    let currentVol = AudioService.sink.audio.volume;
                    let safeVol = AudioService.protectedSetVolume(AudioService.sink, steppedValue, currentVol);           
                    AudioService.sink.audio.volume = safeVol;
                    if (safeVol !== steppedValue) value = safeVol;
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.NoButton // 💡 Lets clicks pass through to the slider!
                onWheel: (wheel) => root.changeVolume(wheel.angleDelta.y, 0.01)
            }
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