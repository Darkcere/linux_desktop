import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: btMenuRoot
    color: "transparent"
    
    // Card styling
    border.color: Colors.border
    border.width: 2
    radius: 20
    clip: true 
    
    signal closeRequested()
    
    // Track if Bluetooth is actually powered on
    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12
        
        // --- HEADER ---
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Bluetooth Devices"
                color: Colors.text
                font.pixelSize: 15
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            
            // Scan / Search Button
            Rectangle {
                id: scanBtn
                width: 28; height: 28; radius: 14
                color: "transparent"
                visible: btMenuRoot.btEnabled 
                
                property bool isScanning: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
                
                Text { 
                    id: scanIcon
                    anchors.centerIn: parent
                    text: scanBtn.isScanning ? "󰑐" : "󰍉" 
                    color: scanBtn.isScanning ? Colors.workspaceactive : Colors.text
                    font.pixelSize: 16 
                    
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1000
                        running: scanBtn.isScanning
                        
                        onRunningChanged: {
                            if (!running) scanIcon.rotation = 0;
                        }
                    }
                }
                
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!Bluetooth.defaultAdapter) return;
                        
                        // Toggle the discovering state directly
                        Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
                    }
                }
            }
        }
        
        // --- CONTENT AREA ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // 1. DEVICE LIST
            ListView {
                id: btListView
                anchors.fill: parent
                // 💡 FIX 2: Removed ListView spacing. It creates empty gaps if we hide items. 
                // We handle spacing in the delegate now.
                clip: true 
                visible: btMenuRoot.btEnabled
                
                model: Bluetooth.devices
                
                delegate: Item {
                    id: delegateRoot
                    width: ListView.view.width
                    
                    property bool showDevice: modelData.paired || (modelData.name && modelData.name.trim() !== "")
                    
                    height: showDevice ? 52 : 0 
                    visible: showDevice
                    clip: true

                    Rectangle {
                        id: deviceCard // 💡 ADDED ID to ensure reliable state tracking
                        width: parent.width
                        height: 44
                        radius: 12
                        
                        property bool isConn: modelData.connected
                        property bool isPaired: modelData.paired

                        color: deviceCard.isConn ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15) : "transparent"
                        border.color: deviceCard.isConn ? Colors.workspaceactive : Colors.border
                        border.width: 1
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (deviceCard.isPaired) {
                                    deviceMenu.popup(mouse.x, mouse.y);
                                }
                            }
                        }

                        Menu {
                            id: deviceMenu
                            background: Rectangle {
                                implicitWidth: 130
                                implicitHeight: 72
                                color: Colors.background
                                border.color: Colors.border; border.width: 2
                                radius: 8
                            }
                            
                            MenuItem {
                                id: trustItem
                                text: modelData.trusted ? "Untrust Device" : "Trust Device"
                                
                                contentItem: Text {
                                    text: trustItem.text
                                    color: trustItem.hovered ? Colors.background : Colors.text
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: trustItem.hovered ? Colors.workspaceactive : "transparent"
                                    radius: 6
                                }
                                
                                onTriggered: {
                                    modelData.trusted = !modelData.trusted;
                                }
                            }
                            
                            MenuItem {
                                id: forgetItem
                                text: "Forget Device"
                                
                                contentItem: Text {
                                    text: forgetItem.text
                                    color: forgetItem.hovered ? Colors.background : Colors.text
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: forgetItem.hovered ? Colors.workspaceactive : "transparent"
                                    radius: 6
                                }
                                
                                onTriggered: {
                                    modelData.forget();
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            Text {
                                text: deviceCard.isConn ? "󰂱" : "󰂯"
                                color: deviceCard.isConn ? Colors.workspaceactive : Colors.text
                                opacity: deviceCard.isConn ? 1.0 : 0.6
                                font.pixelSize: 16
                            }

                            Text {
                                text: modelData.name || modelData.address || "Unknown Device"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: deviceCard.isConn ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 70 
                                Layout.preferredHeight: 24
                                radius: 6
                                // 💡 Bind directly to modelData
                                color: modelData.connected ? Colors.workspaceactive : "transparent"
                                border.color: modelData.connected ? "transparent" : Colors.border
                                border.width: modelData.connected ? 0 : 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    
                                    // 💡 Strictly read from modelData instead of a custom property
                                    text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                                    
                                    color: modelData.connected ? Colors.background : Colors.text
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.connected) {
                                            modelData.disconnect();
                                        } else if (modelData.paired) {
                                            modelData.connect();
                                        } else {
                                            modelData.pair();
                                            modelData.trusted = true; 
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. NO DEVICES MESSAGE
            Text {
                anchors.centerIn: parent
                visible: btMenuRoot.btEnabled && btListView.count === 0
                text: "No devices found"
                color: Colors.text
                opacity: 0.5
            }
            
            // 3. BLUETOOTH OFF MESSAGE
            ColumnLayout {
                anchors.centerIn: parent
                visible: !btMenuRoot.btEnabled
                spacing: 15
                
                Text {
                    text: "󰂲"
                    color: Colors.text
                    opacity: 0.4
                    font.pixelSize: 42
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "Bluetooth is turned off"
                    color: Colors.text
                    opacity: 0.6
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}