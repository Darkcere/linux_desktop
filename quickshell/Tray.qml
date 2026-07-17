import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: trayContainerWrapper
    visible: trayRepeater.count > 0
    implicitWidth: trayContentRow.width + 8
    implicitHeight: 24

    required property var menuHandler

    property Item hoveredItem: null
    property string hoveredTitle: ""

    // --- 1. BACKGROUND (no clip needed — accent bar gets its own radius) ---
    Rectangle {
        anchors.fill: parent
        color: '#00040e0d'
        radius: 5

        Rectangle {
            implicitWidth: 2
            implicitHeight: 13
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.border
        }
    }

    // --- 2. ROW POSITIONER ---
    Row {
        id: trayContentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 3

        Repeater {
            id: trayRepeater
            model: SystemTray.items
            delegate: MouseArea {
                id: trayItemMouseArea
                implicitWidth: 15
                implicitHeight: 15
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                required property var modelData

                onContainsMouseChanged: {
                    if (containsMouse) {
                        trayContainerWrapper.hoveredItem = trayItemMouseArea;
                        trayContainerWrapper.hoveredTitle = modelData.tooltipTitle || modelData.title || "";
                    } else if (trayContainerWrapper.hoveredItem === trayItemMouseArea) {
                        trayContainerWrapper.hoveredItem = null;
                        trayContainerWrapper.hoveredTitle = "";
                    }
                }

                // Clear the tooltip state if this delegate is destroyed while hovered
                // (e.g. the tray app quits/removes its icon mid-hover)
                Component.onDestruction: {
                    if (trayContainerWrapper.hoveredItem === trayItemMouseArea) {
                        trayContainerWrapper.hoveredItem = null;
                        trayContainerWrapper.hoveredTitle = "";
                    }
                }

                IconImage {
                    id: trayIcon
                    anchors.fill: parent
                    asynchronous: true   // decode off the main thread, avoids UI stalls
                    mipmap: false        // no benefit at fixed 15x15, saves RAM+CPU
                    source: {
                        var currentIcon = modelData.icon.toString().toLowerCase();
                        if (currentIcon.includes("spotify")) {
                            return Quickshell.iconPath("spotify-client");
                        }
                        return modelData.icon;
                    }
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.title ? modelData.title.substring(0, 2).toUpperCase() : "??"
                    visible: trayIcon.status !== Image.Ready
                    color: "#ffffff"
                    font.pixelSize: 10
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (modelData.onlyMenu && modelData.hasMenu) {
                            trayContainerWrapper.menuHandler.toggleTrayMenu(modelData);
                        } else {
                            modelData.activate();
                        }
                    } else if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                            trayContainerWrapper.menuHandler.toggleTrayMenu(modelData);
                        }
                    }
                    mouse.accepted = true;
                }
            }
        }
    }

    // --- 4. TOOLTIP ---
    BarToolTip {
        targetItem: trayContainerWrapper.hoveredItem || trayContainerWrapper
        active: trayContainerWrapper.hoveredItem !== null
        text: trayContainerWrapper.hoveredTitle
        topMargin: 22
    }
}