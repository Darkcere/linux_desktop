import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    property bool isOpen: false
    signal closeRequested()
    
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    // --- CUSTOM STYLED SLIDER WITH BREATHING ANIMATION & HOVER EFFECTS ---
    component VolumeSlider: Slider {
        id: control
        Layout.fillWidth: true
        from: 0
        to: 1
        
        // Enable hover detection for the slider
        hoverEnabled: true 
        
        property bool isPlaying: false
        
        background: Rectangle {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 6
            width: control.availableWidth
            height: implicitHeight
            radius: 3
            color: Colors.secondary 

            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                color: Colors.workspaceactive 
                radius: 3
                
                // --- BREATHING GLOW ANIMATION ---
                Rectangle {
                    id: glowRect
                    anchors.fill: parent
                    radius: 3
                    color: Colors.text 
                    opacity: 0
                    
                    states: State {
                        name: "playing"; when: control.isPlaying
                    }
                    
                    transitions: [
                        Transition {
                            from: "*"; to: "playing"
                            SequentialAnimation {
                                loops: Animation.Infinite
                                NumberAnimation { target: glowRect; property: "opacity"; from: 0.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                NumberAnimation { target: glowRect; property: "opacity"; from: 0.4; to: 0.0; duration: 800; easing.type: Easing.InOutSine }
                            }
                        },
                        Transition {
                            from: "playing"; to: "*"
                            NumberAnimation { target: glowRect; property: "opacity"; to: 0.0; duration: 300 }
                        }
                    ]
                }
            }
        }
        
        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 14
            implicitHeight: 14
            radius: 7
            
            // Change color based on pressed/hovered states
            color: control.pressed ? Colors.workspaceurgent 
                                   : (control.hovered ? Colors.workspaceactive : Colors.text)
            
            // Pop the handle size up slightly when interacting
            scale: (control.hovered || control.pressed) ? 1.25 : 1.0
            
            // Smooth transitions for the hover/press effects
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // --- SPEAKER VOLUME ---
        Text { text: "Output"; color: Colors.workspaceempty; font.pixelSize: 12; font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text { 
                text: Pipewire.defaultAudioSink?.audio.muted ? "󰝟" : "󰕾"
                color: Pipewire.defaultAudioSink?.audio.muted ? Colors.workspaceurgent : Colors.text
                font.pixelSize: 16
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
            }
            
            VolumeSlider {
                value: Pipewire.defaultAudioSink?.audio.volume ?? 0
                isPlaying: Pipewire.defaultAudioSink?.state === 3
                onValueChanged: if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = value
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: (wheel) => { if (Pipewire.defaultAudioSink) { let s = 0.05; Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, Pipewire.defaultAudioSink.audio.volume + (wheel.angleDelta.y > 0 ? s : -s))); } } }
            }
            
            Text { text: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100) + "%"; color: Colors.text; font.pixelSize: 14; Layout.minimumWidth: 35; horizontalAlignment: Text.AlignRight }
        }

        // --- MICROPHONE VOLUME ---
        Text { text: "Input"; color: Colors.workspaceempty; font.pixelSize: 12; font.bold: true; Layout.topMargin: 8 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text { 
                text: Pipewire.defaultAudioSource?.audio.muted ? "󰍭" : "󰍬"
                color: Pipewire.defaultAudioSource?.audio.muted ? Colors.workspaceurgent : Colors.text
                font.pixelSize: 16
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSource) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted }
            }
            
            VolumeSlider {
                value: Pipewire.defaultAudioSource?.audio.volume ?? 0
                isPlaying: Pipewire.defaultAudioSource?.state === 3
                onValueChanged: if (Pipewire.defaultAudioSource) Pipewire.defaultAudioSource.audio.volume = value
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: (wheel) => { if (Pipewire.defaultAudioSource) { let s = 0.05; Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1, Pipewire.defaultAudioSource.audio.volume + (wheel.angleDelta.y > 0 ? s : -s))); } } }
            }

            Text { text: Math.round((Pipewire.defaultAudioSource?.audio.volume ?? 0) * 100) + "%"; color: Colors.text; font.pixelSize: 14; Layout.minimumWidth: 35; horizontalAlignment: Text.AlignRight }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; Layout.topMargin: 8; Layout.bottomMargin: 2 }

        // --- PLAYBACK STREAMS ---
        Text { text: "Apps Playing Audio"; color: Colors.workspaceempty; font.pixelSize: 12; font.bold: true }
        
        ScrollView {
            id: appScrollView 
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            
            // --- CUSTOM STYLED SCROLLBAR ON THE RIGHT ---
            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: ScrollBar.AsNeeded
                
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                
                contentItem: Rectangle {
                    implicitWidth: 6
                    implicitHeight: 40
                    radius: 3
                    
                    color: vbar.pressed ? Colors.workspaceurgent 
                                        : (vbar.hovered ? Colors.workspaceactive : Colors.secondary)
                    
                    opacity: vbar.active ? 1.0 : 0.5
                    
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                
                background: Rectangle {
                    implicitWidth: 6
                    color: "transparent"
                }
            }
            
            Column {
                width: appScrollView.width - (vbar.visible ? vbar.width + 6 : 0)
                spacing: 8
                
                Repeater {
                    model: Pipewire.nodes
                    delegate: ColumnLayout {
                        width: parent.width 
                        PwObjectTracker { objects: [modelData] }

                        property bool valid: modelData !== null
                        property var props: valid && modelData.properties ? modelData.properties : ({})
                        property bool isPlaybackStream: (props["media.class"] === "Stream/Output/Audio")
                        property var pwAudio: valid ? modelData.audio : null
                        
                        visible: isPlaybackStream

                        Text { 
                            text: props["application.name"] || props["media.name"] || modelData.name || "Unknown App"
                            color: Colors.text; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10; Layout.bottomMargin: 10
                            
                            VolumeSlider {
                                value: pwAudio ? pwAudio.volume : 0
                                isPlaying: valid && modelData.state === 3
                                onValueChanged: if (pwAudio) pwAudio.volume = value
                                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: (wheel) => { if (pwAudio) { let s = 0.05; pwAudio.volume = Math.max(0, Math.min(1, pwAudio.volume + (wheel.angleDelta.y > 0 ? s : -s))); } } }
                            }

                            Text { text: Math.round((pwAudio ? pwAudio.volume : 0) * 100) + "%"; color: Colors.text; font.pixelSize: 14; Layout.minimumWidth: 35; horizontalAlignment: Text.AlignRight }
                        }
                    }
                }
            }
        }
    }
}