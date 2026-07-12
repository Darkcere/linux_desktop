import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: menuRoot

    property var activeItem: null
    property bool isOpen: false

    signal closeRequested()

    implicitWidth: menuLayout.implicitWidth + 20
    implicitHeight: menuLayout.implicitHeight + 12

    Shortcut {
        sequence: "Escape"
        onActivated: menuRoot.closeRequested()
    }

    QsMenuOpener {
        id: menuOpener
        menu: menuRoot.activeItem ? menuRoot.activeItem.menu : null
    }

    ColumnLayout {
        id: menuLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        spacing: 2

        Repeater {
            model: menuOpener.children ? menuOpener.children.values : []

            delegate: ColumnLayout {
                id: topDelegate
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                property bool submenuExpanded: false
                property string cleanText: modelData.text ? modelData.text.replace(/&/g, "") : ""

                // --- Divider Line ---
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    opacity: 0.5
                    color: Colors.border
                    visible: modelData.isSeparator
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                }

                // --- MAIN MENU ITEM ---
                Rectangle {
                    visible: !modelData.isSeparator
                    Layout.fillWidth: true
                    implicitHeight: 24
                    implicitWidth: Math.max(160, menuContentRow.implicitWidth + 16)
                    color: itemMouseArea.containsMouse ? Colors.workspaceactive : "transparent"
                    radius: 3

                    RowLayout {
                        id: menuContentRow
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        opacity: (modelData.enabled !== undefined && !modelData.enabled) ? 0.5 : 1.0

                        Text {
                            text: "✓"
                            color: Colors.text
                            font.pixelSize: 11
                            visible: modelData.checked || false
                        }
                        Text {
                            Layout.fillWidth: true
                            text: topDelegate.cleanText
                            color: Colors.text
                            font.pixelSize: 11
                        }
                        Text {
                            visible: modelData.hasChildren || false
                            text: topDelegate.submenuExpanded ? "▾" : "▸"
                            color: Colors.text
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.enabled !== undefined ? modelData.enabled : true

                        onClicked: {
                            if (modelData.hasChildren) {
                                topDelegate.submenuExpanded = !topDelegate.submenuExpanded;
                            } else if (modelData.enabled !== false) {
                                if (modelData.triggered) modelData.triggered();
                                else if (modelData.activate) modelData.activate();
                                menuRoot.closeRequested();
                            }
                        }
                    }
                }

                // --- Submenu Container: lazily loaded ---
                // Loader only instantiates QsMenuOpener (and its D-Bus menu query)
                // once the user actually expands this item, instead of eagerly
                // for every item-with-children when the parent menu opens.
                Loader {
                    Layout.fillWidth: true
                    active: topDelegate.submenuExpanded && (modelData.hasChildren || false)
                    visible: active

                    sourceComponent: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QsMenuOpener {
                            id: subMenuOpener
                            menu: modelData.hasChildren ? modelData : null
                        }

                        Repeater {
                            model: subMenuOpener.children ? subMenuOpener.children.values : []

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                property string cleanText: modelData.text ? modelData.text.replace(/&/g, "") : ""

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    opacity: 0.3
                                    color: Colors.border
                                    visible: modelData.isSeparator
                                    Layout.topMargin: 2
                                    Layout.bottomMargin: 2
                                }

                                Rectangle {
                                    id: subItemRect
                                    visible: !modelData.isSeparator
                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    implicitWidth: Math.max(160, subMenuText.implicitWidth + 36)
                                    color: subItemMouseArea.containsMouse ? Colors.workspaceactive : "transparent"
                                    radius: 3

                                    Text {
                                        id: subMenuText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: subItemRect.parent.cleanText
                                        color: Colors.text
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: subItemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (modelData.triggered) modelData.triggered();
                                            else if (modelData.activate) modelData.activate();
                                            menuRoot.closeRequested();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}