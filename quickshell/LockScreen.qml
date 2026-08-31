import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pam

Scope {
    id: root
    
    property bool isLocked: false
    property bool unlockInProgress: false
    property bool isUnlocking: false 
    property string currentPassword: ""
    property int shakeTrigger: 0

    // 💡 NEW: Signal to tell shell.qml to destroy this component from memory
    signal unlocked()

    // ==========================================
    // 💡 NATIVE PAM AUTHENTICATION
    // ==========================================
    PamContext {
        id: pam
        config: "su"
        
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentPassword);
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.currentPassword = "";
                root.isUnlocking = true; 
                unlockTimer.start(); 
            } else {
                root.currentPassword = "";
                root.shakeTrigger += 1; 
                root.unlockInProgress = false;
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 1200 
        onTriggered: {
            root.isLocked = false;
            root.isUnlocking = false;
            root.unlockInProgress = false;
            Quickshell.execDetached({ command: ["rm", "-f", "/tmp/qs_is_locked", "/tmp/qs_locked"] });
            
            // 💡 NEW: Tell the Loader in shell.qml to deactivate and garbage collect
            root.unlocked();
        }
    }

    // ==========================================
    // 💡 TRUE WAYLAND SESSION LOCK
    // ==========================================
    WlSessionLock {
        id: sessionLock
        locked: root.isLocked
        
        WlSessionLockSurface {
            id: lockSurfaceRoot

            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            Item {
                id: screenRoot
                anchors.fill: parent

                property real revealProgress: 0.0 

                // ==========================================
                // 💡 THE DROPLET MASK SHAPE
                // ==========================================
                Rectangle {
                    id: dropletMask
                    visible: false 
                    
                    width: 200 + (screenRoot.width - 200) * screenRoot.revealProgress
                    height: 40 + (screenRoot.height - 40) * screenRoot.revealProgress
                    x: (screenRoot.width / 2) - (width / 2)
                    y: 0
                    radius: 100 * (1 - screenRoot.revealProgress)
                    color: "black" 
                }

                // ==========================================
                // 💡 THE REVEALED LOCKSCREEN CONTENT
                // ==========================================
                Item {
                    id: maskedContent
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: dropletMask
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.4) 
                        
                        Image {
                            anchors.fill: parent
                            source: "file:///home/" + (Quickshell.env("USER") || "duarte") + "/.current.wall"
                            fillMode: Image.PreserveAspectCrop
                            z: -1 
                        }

                        Item {
                            id: uiContainer
                            anchors.fill: parent
                            opacity: 0 
                            scale: 1.1

                            MouseArea {
                                anchors.fill: parent
                                onClicked: passwordField.forceActiveFocus()
                            }

                            // ==========================================
                            // CENTER CONSOLE: CLOCK, PROFILE & AUTH
                            // ==========================================
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 40

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 5
                                    
                                    Text {
                                        id: timeText
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Qt.formatTime(new Date(), "HH:mm")
                                        color: "white"
                                        font.pixelSize: 100 
                                        font.weight: Font.Bold
                                        
                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            transparentBorder: true
                                            color: Qt.rgba(0, 0, 0, 0.5)
                                            radius: 12
                                            samples: 25
                                            verticalOffset: 4
                                        }
                                    }
                                    
                                    Text {
                                        id: dateText
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Qt.formatDate(new Date(), "dddd, d MMMM")
                                        color: "white"
                                        font.pixelSize: 18 
                                        font.weight: Font.Medium
                                        opacity: 0.8
                                    }
                                    
                                    Timer {
                                        interval: 1000
                                        running: root.isLocked
                                        repeat: true
                                        onTriggered: {
                                            let d = new Date();
                                            timeText.text = Qt.formatTime(d, "HH:mm");
                                            dateText.text = Qt.formatDate(d, "dddd, d MMMM");
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 15

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 180 
                                        height: 180
                                        
                                        Rectangle { id: pfpMask; anchors.fill: parent; radius: 90; visible: false }
                                        
                                        Image {
                                            id: profilePic
                                            anchors.fill: parent
                                            source: "file:///home/" + (Quickshell.env("USER") || "duarte") + "/.face.icon"
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.effect: OpacityMask { maskSource: pfpMask }
                                        }

                                        Rectangle {
                                            anchors.fill: parent; radius: 90; color: "transparent"
                                            border.color: Qt.rgba(255, 255, 255, 0.15); border.width: 2
                                        }

                                        Text {
                                            anchors.centerIn: parent; text: ""; color: "white"; font.pixelSize: 80 
                                            opacity: 0.8; visible: profilePic.status !== Image.Ready
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Quickshell.env("USER") || "duarte"
                                        color: "white"; font.pixelSize: 20; font.weight: Font.DemiBold
                                    }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 10

                                    Rectangle {
                                        id: inputContainer
                                        Layout.preferredWidth: 320
                                        Layout.preferredHeight: 52
                                        radius: 26
                                        color: Qt.rgba(0, 0, 0, 0.4)
                                        border.color: root.isUnlocking ? Colors.workspaceactive : (passwordField.activeFocus ? Colors.workspaceactive : Qt.rgba(255, 255, 255, 0.15))
                                        border.width: 2
                                        
                                        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutBounce } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Connections {
                                            target: root
                                            function onShakeTriggerChanged() {
                                                passwordField.text = "";
                                                passwordField.forceActiveFocus();
                                                errorLabel.opacity = 1;
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 5

                                            Item {
                                                width: 40; height: 40
                                                Text { 
                                                    anchors.centerIn: parent
                                                    text: root.isUnlocking ? "󰈈" : "" 
                                                    color: root.isUnlocking ? Colors.workspaceactive : "white"
                                                    opacity: root.isUnlocking ? 1.0 : 0.5
                                                    font.pixelSize: 16 
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }

                                            TextInput {
                                                id: passwordField
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: "white"
                                                font.pixelSize: 20
                                                echoMode: TextInput.Password
                                                passwordCharacter: "•"
                                                clip: true
                                                focus: true 
                                                enabled: !root.isUnlocking

                                                onTextChanged: {
                                                    errorLabel.opacity = 0;
                                                    root.currentPassword = text;
                                                }

                                                onAccepted: {
                                                    if (text.length > 0 && !root.unlockInProgress) {
                                                        root.unlockInProgress = true;
                                                        pam.start();
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 40; height: 40; radius: 20
                                                color: root.isUnlocking ? Colors.workspaceactive : (passwordField.text.length > 0 ? Colors.workspaceactive : Qt.rgba(255, 255, 255, 0.1))
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.isUnlocking ? "󰈈" : (root.unlockInProgress ? "󰔟" : "") 
                                                    color: root.isUnlocking ? "black" : "white"
                                                    font.pixelSize: 18
                                                    opacity: passwordField.text.length > 0 ? 1.0 : 0.4
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: passwordField.text.length > 0 && !root.unlockInProgress && !root.isUnlocking
                                                    onClicked: {
                                                        root.unlockInProgress = true;
                                                        pam.start();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        id: errorLabel
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Incorrect password"
                                        color: "#ff5555"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        opacity: 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }

                            // ==========================================
                            // BOTTOM LEFT: MEDIA PLAYER
                            // ==========================================
                            Rectangle {
                                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 40
                                width: 360; height: 74; radius: 37
                                color: Qt.rgba(0, 0, 0, 0.4); border.color: Qt.rgba(255, 255, 255, 0.1); border.width: 1
                                
                                property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
                                opacity: player ? 1 : 0; visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 15

                                    Item {
                                        Layout.preferredWidth: 54; Layout.preferredHeight: 54
                                        Rectangle { id: artMask; anchors.fill: parent; radius: 27; visible: false }
                                        Image {
                                            anchors.fill: parent; source: parent.parent.parent.player ? parent.parent.parent.player.trackArtUrl : ""
                                            fillMode: Image.PreserveAspectCrop; layer.enabled: true; layer.effect: OpacityMask { maskSource: artMask }
                                        }
                                        Rectangle { anchors.fill: parent; radius: 27; color: "transparent"; border.color: Qt.rgba(255,255,255,0.1); border.width: 1 }
                                        Text { anchors.centerIn: parent; text: "󰝚"; color: "white"; font.pixelSize: 20; opacity: 0.5; visible: parent.children[1].status !== Image.Ready }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                                        Text {
                                            Layout.fillWidth: true; text: parent.parent.parent.player ? parent.parent.parent.player.trackTitle : "No Media"
                                            color: "white"; font.pixelSize: 14; font.weight: Font.Bold; elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true; text: parent.parent.parent.player ? parent.parent.parent.player.trackArtist : "Unknown Artist"
                                            color: "white"; opacity: 0.6; font.pixelSize: 12; elide: Text.ElideRight
                                        }
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Text { text: "󰒮"; color: "white"; opacity: 0.8; font.pixelSize: 20; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.parent.player?.previous() } }
                                        Rectangle {
                                            width: 40; height: 40; radius: 20; color: Colors.workspaceactive
                                            Text { anchors.centerIn: parent; text: (parent.parent.parent.parent.player && parent.parent.parent.parent.player.playbackState === 1) ? "󰏤" : "󰐊"; color: Colors.background; font.pixelSize: 20 }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.parent.player?.togglePlaying() }
                                        }
                                        Text { text: "󰒭"; color: "white"; opacity: 0.8; font.pixelSize: 20; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.parent.player?.next() } }
                                    }
                                }
                            }

                            // ==========================================
                            // BOTTOM RIGHT: POWER ACTIONS
                            // ==========================================
                            Rectangle {
                                anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 40
                                width: 240; height: 60; radius: 30 
                                color: Qt.rgba(0, 0, 0, 0.4); border.color: Qt.rgba(255, 255, 255, 0.1); border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 22; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "󰤄"; color: "white"; opacity: 0.8; font.pixelSize: 20 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; 
                                            onEntered: parent.color = Qt.rgba(255,255,255,0.1); 
                                            onExited: parent.color = "transparent"; 
                                            onClicked: Quickshell.execDetached({ command: ["loginctl", "suspend"] }) 
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 22; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "󰍃"; color: "white"; opacity: 0.8; font.pixelSize: 20 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; 
                                            onEntered: parent.color = Qt.rgba(255,255,255,0.1); 
                                            onExited: parent.color = "transparent"; 
                                            onClicked: Quickshell.execDetached({ command: ["hyprctl", "dispatch", "exit"] }) 
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 22; color: "transparent"
                                        Text { anchors.centerIn: parent; text: "󰜉"; color: "white"; opacity: 0.8; font.pixelSize: 20 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; 
                                            onEntered: parent.color = Qt.rgba(255,255,255,0.1); 
                                            onExited: parent.color = "transparent"; 
                                            onClicked: Quickshell.execDetached({ command: ["loginctl", "reboot"] }) 
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 22; color: "#ff5555"
                                        Text { anchors.centerIn: parent; text: "󰐥"; color: "white"; font.pixelSize: 20 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; 
                                            onEntered: parent.color = "#ff7777"; 
                                            onExited: parent.color = "#ff5555"; 
                                            onClicked: Quickshell.execDetached({ command: ["loginctl", "poweroff"] }) 
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ==========================================
                // 💡 LELOUCH'S GEASS (Zero-Lag SVG Implementation)
                // ==========================================
                Item {
                    id: geassVisuals
                    anchors.fill: parent
                    z: 100 
                    
                    Rectangle {
                        id: geassTint
                        anchors.fill: parent
                        color: Colors.workspaceactive
                        opacity: 0
                    }

                    Rectangle {
                        id: geassRing1
                        anchors.centerIn: parent
                        width: 100; height: 100
                        radius: 50
                        color: "transparent"
                        border.color: Colors.workspaceactive
                        border.width: 6
                        opacity: 0
                    }

                    Item {
                        id: geassSigilContainer
                        anchors.centerIn: parent
                        width: 400
                        height: 400
                        opacity: 0
                        scale: 0.1
                        rotation: -90
                        
                        Image {
                            id: rawGeassSvg
                            anchors.fill: parent
                            sourceSize.width: 400
                            sourceSize.height: 400
                            visible: false 
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 400 400'><path d='M 200 360 C 50 200, 20 80, 200 40 C 380 80, 350 200, 200 360' fill='none' stroke='white' stroke-width='12' stroke-linecap='round'/><path d='M 200 300 C 100 180, 80 100, 200 80 C 320 100, 300 180, 200 300' fill='none' stroke='white' stroke-width='8' stroke-linecap='round'/><path d='M 200 150 L 230 200 L 200 250 L 170 200 Z' fill='white'/></svg>"
                        }
                        
                        ColorOverlay {
                            anchors.fill: rawGeassSvg
                            source: rawGeassSvg
                            color: Colors.workspaceactive
                        }
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            color: Colors.workspaceactive
                            radius: 35
                            samples: 25
                            transparentBorder: true
                        }
                    }
                }

                // ==========================================
                // 💡 DRAMATIC, SLOWED-DOWN ANIMATIONS
                // ==========================================
                
                Component.onCompleted: introAnim.start()

                ParallelAnimation {
                    id: introAnim
                    
                    // Reveal takes a bit longer to look like a curtain opening
                    NumberAnimation { target: screenRoot; property: "revealProgress"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutExpo }
                    
                    // The UI drops in slowly over nearly a second
                    NumberAnimation { target: uiContainer; property: "opacity"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
                    NumberAnimation { target: uiContainer; property: "scale"; from: 0.90; to: 1; duration: 1000; easing.type: Easing.OutBack }
                    NumberAnimation { target: uiContainer; property: "y"; from: 40; to: 0; duration: 1000; easing.type: Easing.OutBack }

                    // The Geass tint fades slowly
                    NumberAnimation { target: geassTint; property: "opacity"; from: 0.7; to: 0.0; duration: 1000; easing.type: Easing.OutSine }
                    
                    // The Geass sigil slams in powerfully and takes its time fading out
                    NumberAnimation { target: geassSigilContainer; property: "scale"; from: 8.0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
                    NumberAnimation { target: geassSigilContainer; property: "opacity"; from: 1.0; to: 0.0; duration: 900; easing.type: Easing.OutExpo }
                    NumberAnimation { target: geassSigilContainer; property: "rotation"; from: 90; to: 0; duration: 900; easing.type: Easing.OutBack }
                }

                ParallelAnimation {
                    id: outroAnim
                    
                    
                    // The UI gets sucked back in smoothly
                    NumberAnimation { target: uiContainer; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InCubic }
                    NumberAnimation { target: uiContainer; property: "scale"; to: 1.10; duration: 800; easing.type: Easing.InBack }
                    NumberAnimation { target: uiContainer; property: "y"; to: -50; duration: 800; easing.type: Easing.InBack }

                    // The Geass activation effect - takes a full second to expand towards the camera
                    NumberAnimation { target: geassTint; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InExpo }
                    NumberAnimation { target: geassSigilContainer; property: "opacity"; to: 1.0; duration: 300 }
                    NumberAnimation { target: geassSigilContainer; property: "scale"; from: 0.1; to: 25.0; duration: 1000; easing.type: Easing.InExpo }
                    NumberAnimation { target: geassSigilContainer; property: "rotation"; from: -90; to: 0; duration: 1000; easing.type: Easing.OutBack }
                    
                    // Shockwave ring effect
                    NumberAnimation { target: geassRing1; property: "opacity"; from: 1; to: 0; duration: 1000 }
                    NumberAnimation { target: geassRing1; property: "scale"; from: 1; to: 35; duration: 1000; easing.type: Easing.OutExpo }
                }

                Connections {
                    target: root
                    function onIsUnlockingChanged() {
                        if (root.isUnlocking) {
                            outroAnim.start()
                        }
                    }
                }
            }
        }
    }
}