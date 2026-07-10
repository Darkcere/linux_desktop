import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    
    property bool isOpen: false
    property var activeTrayItem: null
    
    signal closeRequested()
    
    // Export dimensions so DropdownWindow can morph to fit the menu
    property int requiredWidth: Math.max(200, menuLayout.implicitWidth + 24)
    property int requiredHeight: menuLayout.implicitHeight + 12

    QsMenuOpener {
        id: menuOpener
        menu: root.activeTrayItem ? root.activeTrayItem.menu : null
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
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                property bool submenuExpanded: false

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
                    property string cleanText: modelData.text ? modelData.text.replace(/&/g, "") : ""
                    
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
                            text: parent.parent.cleanText
                            color: Colors.text
                            font.pixelSize: 11
                        }
                        Text {
                            visible: modelData.hasChildren || false
                            text: submenuExpanded ? "▾" : "▸"
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
                                submenuExpanded = !submenuExpanded;
                            } else if (modelData.enabled !== false) {
                                if (modelData.triggered) modelData.triggered();
                                else if (modelData.activate) modelData.activate();
                                root.closeRequested(); // Notify DropdownWindow to close
                            }
                        }
                    }
                }

                // --- Submenu Container ---
                ColumnLayout {
                    id: submenuContainer
                    visible: parent.submenuExpanded && (modelData.hasChildren || false)
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
                            
                            // --- Submenu Divider Line ---
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                opacity: 0.3
                                color: Colors.border
                                visible: modelData.isSeparator
                                Layout.topMargin: 2
                                Layout.bottomMargin: 2
                            }

                            // --- SUBMENU ITEM ---
                            Rectangle {
                                visible: !modelData.isSeparator
                                Layout.fillWidth: true
                                implicitHeight: 24
                                implicitWidth: Math.max(160, subMenuText.implicitWidth + 36)
                                color: subItemMouseArea.containsMouse ? "#1d3631" : "transparent"
                                radius: 3
                                property string cleanText: modelData.text ? modelData.text.replace(/&/g, "") : ""

                                Text {
                                    id: subMenuText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20 
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.cleanText
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
                                        root.closeRequested(); 
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