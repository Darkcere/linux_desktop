//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Controls

ShellRoot {
    PanelWindow {
        id: root
        anchors { top: true; left: true; right: true }
        height: 39
        margins { left: 3; right: 3 }
        exclusionMode: PanelWindow.ExclusionMode.Exclusive
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 7
            color: "transparent"
            border.color: Theme.barBorder
            border.width: 2

            Item {
                id: barInner
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                property int sideMargin: 0 

                // ───── BACKGROUND (Unchanged logic) ─────
                Rectangle {
                    id: barBg
                    anchors.top: parent.top; anchors.bottom: parent.bottom
                    x: barInner.sideMargin; width: parent.width
                    radius: 4; color: Theme.barBackground
                    
                    function cutTo(xPos) {
                        cutX.to = xPos - 10; cutW.to = parent.width - xPos;
                        cutX.restart(); cutW.restart();
                    }
                    function restore() {
                        restoreX.to = 0; restoreW.to = parent.width;
                        restoreX.restart(); restoreW.restart();
                    }
                    NumberAnimation { id: cutX; target: barBg; property: "x"; duration: 520; easing.type: Easing.OutQuint }
                    NumberAnimation { id: cutW; target: barBg; property: "width"; duration: 720; easing.type: Easing.OutQuint }
                    NumberAnimation { id: restoreX; target: barBg; property: "x"; duration: 320; easing.type: Easing.InOutQuad }
                    NumberAnimation { id: restoreW; target: barBg; property: "width"; duration: 320; easing.type: Easing.InOutQuad }
                }

                // ───── THE CLOCK (Perfectly Centered) ─────
                Text {
                    id: clock
                    anchors.centerIn: parent
                    z: 5 // Ensure it stays above the background
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: 14; font.bold: true
                    color: Theme.accent
                    
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
                    }
                }

                // ───── LEFT SIDE: Workspaces ─────
                RowLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    spacing: 10

                    Text { text: "󰣇"; font.pixelSize: 20; color: Theme.accent }

                    Repeater {
                        // This shows workspaces 1-5 ALWAYS, 
                        // plus any workspace higher than 5 if it is occupied.
                        model: {
                            let count = 5;
                            Hyprland.workspaces.values.forEach(ws => {
                                if (ws.id > count) count = ws.id;
                            });
                            return count;
                        }

                        delegate: Rectangle {
                            // index + 1 is the workspace ID
                            property bool active: Hyprland.focusedWorkspace?.id === index + 1
                            property bool occupied: {
                                let found = false;
                                Hyprland.workspaces.values.forEach(ws => {
                                    if (ws.id === index + 1) found = true;
                                });
                                return found;
                            }

                            // Only show if it's 1-5 OR if it's occupied
                            visible: (index < 5) || occupied
                            
                            Layout.preferredWidth: active ? 30 : 10
                            height: 10
                            radius: 5
                            color: active ? Theme.accentActive : Theme.accent
                            opacity: active ? 1.0 : (occupied ? 0.6 : 0.2)

                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 200 } }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch(`workspace ${index + 1}`)
                            }
                        }
                    }
                }

                // ───── RIGHT SIDE: System Tray ─────
                RowLayout {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 10
                    spacing: 8

                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: trayItem
                            implicitWidth: 20; implicitHeight: 20

                            Image {
                                anchors.centerIn: parent
                                source: modelData.icon
                                width: 18; height: 18
                            }

                            QsMenuAnchor {
                                id: menuAnchor
                                menu: modelData.menu

                                anchor.item: trayItem
                                anchor.rect: Qt.rect(
                                    trayItem.width / 2,
                                    trayItem.height + 8,   // ← increase this to move lower
                                    1,
                                    1
                                )

                                onOpened: {
                                    let pos = trayItem.mapToItem(barInner, trayItem.width / 2, 0)
                                    barBg.cutTo(pos.x)
                                }

                                onClosed: barBg.restore()
                            }


                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) modelData.activate()
                                    else if (mouse.button === Qt.RightButton) menuAnchor.open()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}