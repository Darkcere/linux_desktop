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
    enabled: root.Window.visibility !== Window.Hidden

    // Use a binding property. It re-evaluates automatically whenever Mpris.players.values changes.
    property var player: {
        // 1. Get the list and filter out the playerctld daemon
        const rawList = Mpris.players.values;
        const list = rawList.filter(p => !p.dbusName.includes("playerctld"));
        
        if (!list || list.length === 0) return null;

        // 2. Prioritize actively playing
        const active = list.find(p => p.isPlaying);
        if (active) return active;

        // 3. Fallback to existing player if it's still in the filtered list
        if (root.player && list.includes(root.player)) return root.player;

        // 4. Fallback to first available
        return list[0];
    }

    // Connect to global player changes so the binding triggers
    Connections {
        target: Mpris
        function onPlayersChanged() { 
            // Trigger a re-evaluation of the binding by forcing a property refresh
            // We don't set it to null; we let the binding engine do its job.
            root.player = Qt.binding(function() {
                const rawList = Mpris.players.values;
                const list = rawList.filter(p => !p.dbusName.includes("playerctld"));
                if (!list || list.length === 0) return null;
                const active = list.find(p => p.isPlaying);
                if (active) return active;
                if (root.player && list.includes(root.player)) return root.player;
                return list[0];
            });
        }
    }

    // --- PROPERTIES ---
    property string title: player?.trackTitle || ""
    property string artist: player?.trackArtist || ""
    property string albumArt: player?.trackArtUrl ?? ""
    property bool playing: player?.isPlaying ?? false

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
                        
                        // OPTIMIZATION 1: Prevent main-thread freezing when changing tracks
                        asynchronous: true
                        
                        // OPTIMIZATION 2: Cap VRAM usage. Rendered at 44x44 for High-DPI crispness
                        sourceSize: Qt.size(44, 44)
                        
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
            z: -1
        }
        
        Text {
            id: mediaTitle
            visible: root.title
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