import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: menuRoot

    property var activeItem: null
    property bool isOpen: false

    signal closeRequested()

    // 💡 RESTORED: Auto width and height based on the dynamic layout!
    implicitWidth: menuLayout.implicitWidth 
    implicitHeight: menuLayout.implicitHeight + 12

    Shortcut {
        sequence: "Escape"
        onActivated: menuRoot.closeRequested()
    }

    QsMenuOpener {
        id: menuOpener
        menu: menuRoot.activeItem ? menuRoot.activeItem.menu : null
    }

    // 💡 RESTORED: ColumnLayout handles the max-width calculation natively
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
                    
                    // 💡 RESTORED: Dynamically sizes based on the text width!
                    implicitWidth: Math.max(160, mainText.contentWidth + 40)
                    
                    color: itemMouseArea.containsMouse ? Colors.workspaceactive : "transparent"
                    radius: 3

                    // Kept the primitive Item for the row to prevent the D-Bus CPU spikes
                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        opacity: (modelData.enabled !== undefined && !modelData.enabled) ? 0.5 : 1.0

                        Text {
                            id: checkMark
                            text: "✓"
                            color: Colors.text
                            font.pixelSize: 11
                            visible: modelData.checked || false
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            id: mainText
                            text: topDelegate.cleanText
                            color: Colors.text
                            font.pixelSize: 11
                            anchors.left: (modelData.checked || false) ? checkMark.right : parent.left
                            anchors.leftMargin: (modelData.checked || false) ? 8 : 0
                            anchors.right: arrowMark.visible ? arrowMark.left : parent.right
                            anchors.rightMargin: arrowMark.visible ? 8 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight 
                        }
                        
                        Text {
                            id: arrowMark
                            visible: modelData.hasChildren || false
                            text: topDelegate.submenuExpanded ? "▾" : "▸"
                            color: Colors.text
                            font.pixelSize: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
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

                // --- Submenu Container ---
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
                                    visible: !modelData.isSeparator
                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    
                                    // 💡 RESTORED: Dynamic submenu sizing
                                    implicitWidth: Math.max(160, subMenuText.contentWidth + 40)
                                    
                                    color: subItemMouseArea.containsMouse ? Colors.workspaceactive : "transparent"
                                    radius: 3

                                    Text {
                                        id: subMenuText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.parent.cleanText 
                                        color: Colors.text
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
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