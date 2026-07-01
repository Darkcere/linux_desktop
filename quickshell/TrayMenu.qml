import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland 
import Quickshell.Services.SystemTray

PopupWindow {
    id: menuWindow
    visible: false
    
    // This is the native, stable way to handle "click outside to close"
    grabFocus: true 
    
    required property var parentBarWindow
    property var activeItem: null
    property int targetX: 0

    // Reset state when the menu is hidden
    onVisibleChanged: {
        if (!visible) {
            menuWindow.activeItem = null;
        }
    }
    
    anchor {
        window: menuWindow.parentBarWindow
        rect.x: menuWindow.targetX
        rect.y: menuWindow.parentBarWindow.height + 1
    }

    implicitWidth: menuLayout.implicitWidth + 12
    implicitHeight: menuLayout.implicitHeight + 12
    color: "transparent"
    
    Shortcut {
        sequences: ["Escape"]
        onActivated: {
            menuWindow.visible = false
        }
    }
    
    QsMenuOpener {
        id: menuOpener
        menu: menuWindow.activeItem ? menuWindow.activeItem.menu : null
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        border.color: Colors.border
        border.width: 2
        radius: 5

        ColumnLayout {
            id: menuLayout
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            
            Repeater {
                model: menuOpener.children ? menuOpener.children.values : []
                
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    property bool submenuExpanded: false

                    // --- NEW: Divider Line ---
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        opacity: 0.5
                        color: Colors.border // Uses your existing border color
                        visible: modelData.isSeparator 
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    // --- MAIN MENU ITEM ---
                    Rectangle {
                        visible: !modelData.isSeparator // Hide normal item if it's a separator
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
                                    menuWindow.visible = false;
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
                            
                            // Changed delegate to ColumnLayout to support dividers here too
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2
                                
                                // --- NEW: Submenu Divider Line ---
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
                                            menuWindow.visible = false; 
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

    function toggleMenu(trayItem, globalX) {
        if (menuWindow.visible && menuWindow.activeItem === trayItem) {
            menuWindow.visible = false;
        } else {
            menuWindow.activeItem = trayItem;
            menuWindow.targetX = globalX;
            menuWindow.visible = true;
        }
    }
}