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
    
    // 💡 Track if Bluetooth is actually powered on
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
            
            // 💡 Scan / Search Button (Only visible when Bluetooth is ON)
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
                    
                    // Fixed animation target
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1000
                        running: scanBtn.isScanning
                        
                        // Reset rotation to 0 when it stops scanning
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
                        
                        // 💡 Correctly toggle the discovering state using the assignment operator (=)
                        Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
                    }
                }
            }
        }
        
        // --- CONTENT AREA ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // 1. DEVICE LIST (Visible when BT is ON)
            ListView {
                id: btListView
                anchors.fill: parent
                spacing: 8
                clip: true 
                visible: btMenuRoot.btEnabled
                
                model: Bluetooth.devices ? Bluetooth.devices.values : []
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 44
                    radius: 12
                    
                    color: modelData.connected ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15) : "transparent"
                    border.color: modelData.connected ? Colors.workspaceactive : Colors.border
                    border.width: 1
                    
                    // 💡 Right-Click Menu Trigger
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (modelData.paired) {
                                deviceMenu.popup(mouse.x, mouse.y);
                            }
                        }
                    }

                    // 💡 Custom Styled Right-Click Menu
                    Menu {
                        id: deviceMenu
                        background: Rectangle {
                            implicitWidth: 130
                            implicitHeight: 72 // 💡 Increased height to fit two items cleanly
                            color: Colors.background
                            border.color: Colors.border; border.width: 2
                            radius: 8
                        }
                        
                        MenuItem {
                            id: trustItem
                            // 💡 Dynamically changes based on current trust state
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
                                // 💡 Toggle the trusted property directly
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
                            text: modelData.connected ? "󰂱" : "󰂯"
                            color: modelData.connected ? Colors.workspaceactive : Colors.text
                            opacity: modelData.connected ? 1.0 : 0.6
                            font.pixelSize: 16
                        }

                        Text {
                            text: modelData.name || modelData.address || "Unknown Device"
                            color: Colors.text
                            font.pixelSize: 13
                            font.weight: modelData.connected ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        // 💡 Dynamic Action Button 
                        Rectangle {
                            Layout.preferredWidth: 70 
                            Layout.preferredHeight: 24
                            radius: 6
                            color: modelData.connected ? Colors.workspaceactive : "transparent"
                            border.color: modelData.connected ? "transparent" : Colors.border
                            border.width: modelData.connected ? 0 : 1
                            
                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (modelData.connected) return "Disconnect";
                                    if (modelData.paired) return "Connect";
                                    return "Pair"; 
                                }
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
            
            // 2. NO DEVICES MESSAGE (Visible when BT is ON, but list is empty)
            Text {
                anchors.centerIn: parent
                visible: btMenuRoot.btEnabled && btListView.count === 0
                text: "No devices found"
                color: Colors.text
                opacity: 0.5
            }
            
            // 3. BLUETOOTH OFF MESSAGE (Visible when BT is OFF)
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