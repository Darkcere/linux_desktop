import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

Rectangle {
    id: root
    implicitWidth: mainRow.implicitWidth
    implicitHeight: 24
    color: "transparent"
    enabled: root.Window.visibility !== Window.Hidden

    // 💡 THE FIX: Track the last used player asynchronously to avoid QML Binding Loop errors!
    property string lastPlayerName: ""
    onPlayerChanged: {
        if (player) root.lastPlayerName = player.dbusName;
    }

    property var player: {
        const rawList = Mpris.players.values;
        if (!rawList || rawList.length === 0) return null;
        
        const validPlayers = rawList.filter(p => !p.dbusName.includes("playerctld"));
        if (validPlayers.length === 0) return null;

        // 1. Prioritize whoever is actively playing right now
        for (let i = 0; i < validPlayers.length; i++) {
            if (validPlayers[i].isPlaying) return validPlayers[i];
        }
        
        // 2. 💡 THE FIX: If nobody is playing, stick to the player we were just looking at!
        if (root.lastPlayerName !== "") {
            for (let i = 0; i < validPlayers.length; i++) {
                if (validPlayers[i].dbusName === root.lastPlayerName) return validPlayers[i];
            }
        }
        
        // 3. Fallback to the first available player
        return validPlayers[0];
    }

    // --- PROPERTIES ---
    property string title: player?.trackTitle || ""
    property string artist: player?.trackArtist || ""
    property string albumArt: player?.trackArtUrl ?? ""
    property bool playing: player?.isPlaying ?? false

    // --- MAIN LAYOUT ---
    Row {
        id: mainRow
        anchors.fill: parent
        anchors.leftMargin: 4
        spacing: 6
        
        Item {
            id: artContainer
            
            // 💡 THE FIX: Explicitly center vertically inside the primitive Row
            anchors.verticalCenter: parent.verticalCenter
            
            width: 22
            height: 22
            visible: root.player !== null
            
            HoverHandler {
                id: artcontainerHover
            }
            
            Item {
                id: spinnerItem
                anchors.fill: parent
                opacity: root.playing ? 1.0 : 0.7
                
                RotationAnimator {
                    target: spinnerItem
                    from: 0
                    to: 360
                    duration: 13000 
                    loops: Animation.Infinite
                    running: true 
                    paused: !root.playing 
                }

                Rectangle {
                    id: maskRect
                    width: 22; height: 22; radius: 11; visible: false
                }

                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.albumArt !== "") ? artImageComp : vinylComp
                }

                Component {
                    id: artImageComp
                    Image {
                        source: root.albumArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        
                        sourceSize.width: 44
                        sourceSize.height: 44
                        
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: maskRect }
                    }
                }

                Component {
                    id: vinylComp
                    Rectangle {
                        color: Colors.border
                        radius: 11
                        border.width: 2
                        border.color: Colors.background
                        Rectangle {
                            width: 4; height: 4; radius: 2; color: "transparent"; 
                            anchors.centerIn: parent
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Colors.workspaceactive
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
            
            Loader {
                id: controlsLoader
                z: 1000 
                anchors.centerIn: artContainer
                active: artcontainerHover.hovered || controlsHover.hovered 
                HoverHandler {
                    id: controlsHover
                }
                
                visible: opacity > 0
                opacity: active ? 1.0 : 0.0
                
                Behavior on opacity { NumberAnimation { duration: 150 } }
                
                sourceComponent: Component {
                    Rectangle {
                        width: 72; height: 24; radius: 12
                        color: "#CC000000"

                        Row {
                            anchors.centerIn: parent
                            spacing: 20 
                            
                            Text { text: "󰒮"; color: "#FFFFFF"; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.previous() }
                            }
                            Text { text: root.playing ? "󰏤" : "󰐊"; color: "#FFFFFF"; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.togglePlaying() }
                            }
                            Text { text: "󰒭"; color: "#FFFFFF"; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.next() }
                            }
                        }
                    }
                }
            }
        }

        Cavavisualizer {
            // 💡 THE FIX: Explicitly center vertically
            anchors.verticalCenter: parent.verticalCenter
            z: -1
        }
        
        Text {
            id: mediaTitle
            // 💡 THE FIX: Explicitly center vertically
            anchors.verticalCenter: parent.verticalCenter
            
            visible: root.title
            HoverHandler { id: mediaHover }
            
            width: Math.min(implicitWidth, 200)
            
            text: root.artist.length > 0 ? root.title + " • " + root.artist : root.title
            color: Colors.text
            font.pixelSize: 10
            font.weight: Font.Medium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.WhatsThisCursor
            }
        }
        
        BarToolTip {
            targetItem: mediaTitle
            active: mediaHover.hovered 
            text: {
                if (!root.player) return "";
                let albumInfo = root.player?.trackAlbum ? "\n󰀥  " + root.player.trackAlbum : "";
                let artistInfo = root.artist ? "\n󰠃  " + root.artist : "";
                return "󰝚  " + root.title + artistInfo + albumInfo;
            }
            topMargin: 21
        }
    }
}