import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

Rectangle {
    id: root
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: 24
    color: "transparent"
    property var player: null

    function updatePlayer() {
        const list = Mpris.players.values;
        if (!list || list.length === 0) {
            player = null;
            return;
        }

        // 1. Check if any OTHER player is actually playing right now
        const currentlyPlaying = list.find(p => p.isPlaying);

        // 2. STICKINESS LOGIC:
        // If we have a player, and it's playing, keep it.
        // If it's paused, ONLY switch if another player has started playing.
        let target;
        if (root.player && root.player.isPlaying) {
            target = root.player;
        } else if (currentlyPlaying) {
            target = currentlyPlaying;
        } else {
            // Nothing is playing. Keep the current one if it exists, 
            // otherwise default to the first one available.
            target = root.player || list[0];
        }

        if (root.player !== target) {
            root.player = target;
        }
    }

    // --- PROPERTIES ---
    property string title: player?.trackTitle || ""
    property string artist: player?.trackArtist || ""
    property string albumArt: root.player?.trackArtUrl ?? ""
    property bool playing: player?.isPlaying ?? false
    
    Instantiator {
        model: Mpris.players.values
        onObjectAdded: updatePlayer()
        onObjectRemoved: updatePlayer()
        delegate: Connections {
            target: modelData
            ignoreUnknownSignals: true
            function onPlaybackStateChanged() { updatePlayer() }
            function onTrackChanged() { updatePlayer() }
        }
    }

    // --- MAIN LAYOUT ---
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 4
        spacing: 6
        
        Item {
            id: artContainer
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            visible: root.player ? true : false
            // The Spinning Item
            HoverHandler {
                id: artcontainerHover
            }
            Item {
                id: spinnerItem
                anchors.fill: parent

                // This handles the smooth spinning without any timers
                RotationAnimator {
                    target: spinnerItem
                    from: 0
                    to: 360
                    duration: 8000 
                    loops: Animation.Infinite
                    
                    // Keep running: true so it doesn't destroy/reset the animation
                    running: true 
                    
                    // Use paused to stop the movement when NOT playing
                    paused: !root.playing 
                }

                // Mask for the circle shape
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
                            
                            // Buttons remain the same
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
            enabled: root.Window.visibility !== Window.Hidden
            z: -1
        }
        
        Text {
            id: mediaTitle
            HoverHandler { id: mediaHover }
            Layout.maximumWidth: 200
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
                return "󰝚  " + root.title + "\n󰠃  " + root.artist + albumInfo;
            }
            topMargin: 18
        }
    }
}