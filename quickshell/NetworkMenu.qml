import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtCore

Rectangle {
    id: netMenuRoot
    color: "transparent"
    
    // Card styling
    border.color: Colors.border
    border.width: 2
    radius: 20
    clip: true 
    
    signal closeRequested()
    
    // --- WI-FI PROPERTIES ---
    property var wifiDevice: {
        let count = Networking.devices.count;
        let devs = Networking.devices.values;
        for (let i = 0; i < count; i++) {
            if (devs[i] && devs[i].type === NetworkDeviceType.Wifi) {
                return devs[i];
            }
        }
        return null;
    }
    property bool wifiEnabled: Networking.wifiEnabled

    // 💡 Track active tab (false = Wi-Fi, true = VPN)
    // Defaults to true (VPNs) if wifiDevice is null, otherwise false (Wi-Fi)
    property bool isVpnTab: wifiDevice === null

    // --- VPN PROPERTIES & DATA MODEL ---
    ListModel { id: vpnModel }
    
    Process {
        id: fetchVpnsProcess
        // Fetches all connections, filters for VPN/Wireguard/Tun, and outputs Name:Type:Active
        command: ["bash", "-c", "nmcli -t -f NAME,TYPE,ACTIVE connection show | grep -iE 'vpn|wireguard|tun'"]
        stdout: StdioCollector {
            onStreamFinished: {
                vpnModel.clear();
                let lines = text.trim().split('\n');
                for (let line of lines) {
                    if (!line) continue;
                    let parts = line.split(':');
                    if (parts.length >= 3) {
                        vpnModel.append({
                            "name": parts[0],
                            "type": parts[1],
                            "active": parts[2] === "yes"
                        });
                    }
                }
            }
        }
    }

    // Auto-refresh VPNs every 2 seconds ONLY when the VPN tab is open
    Timer {
        interval: 2000
        running: netMenuRoot.isVpnTab
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchVpnsProcess.running = true
    }

    // --- SHARED PROCESSES ---
    Process { id: netActionProcess }
    Process { 
        id: scanProcess
        command: ["nmcli", "device", "wifi", "rescan"]
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12
        
        // ==========================================
        // DYNAMIC CONTENT AREA (WI-FI OR VPN VIEWS)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ---------------------------------
            // VIEW 1: WI-FI NETWORKS
            // ---------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: !netMenuRoot.isVpnTab
                spacing: 12

                // --- WI-FI HEADER ---
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Wi-Fi Networks"
                        color: Colors.text
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        id: scanBtn
                        width: 28; height: 28; radius: 14
                        color: "transparent"
                        visible: netMenuRoot.wifiEnabled && netMenuRoot.wifiDevice !== null
                        
                        Text { 
                            id: scanIcon
                            anchors.centerIn: parent
                            text: scanProcess.running ? "󰑐" : "󰍉" 
                            color: scanProcess.running ? Colors.workspaceactive : Colors.text
                            font.pixelSize: 16 
                            
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1000
                                running: scanProcess.running
                                onRunningChanged: { if (!running) scanIcon.rotation = 0; }
                            }
                        }
                        
                        MouseArea { 
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!scanProcess.running) scanProcess.running = true; }
                        }
                    }
                }

                // --- WI-FI CONTENT ---
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    ListView {
                        id: netListView
                        anchors.fill: parent
                        spacing: 8
                        clip: true 
                        visible: netMenuRoot.wifiEnabled && netMenuRoot.wifiDevice !== null
                        
                        model: netMenuRoot.wifiDevice ? netMenuRoot.wifiDevice.accessPoints.values : []
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: modelData.ssid !== "" ? 44 : 0
                            visible: modelData.ssid !== ""
                            radius: 12
                            
                            color: modelData.active ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15) : "transparent"
                            border.color: modelData.active ? Colors.workspaceactive : Colors.border
                            border.width: 1
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => networkMenu.popup(mouse.x, mouse.y)
                            }

                            Menu {
                                id: networkMenu
                                background: Rectangle {
                                    implicitWidth: 130; implicitHeight: 36 
                                    color: Colors.background; border.color: Colors.border; border.width: 2; radius: 8
                                }
                                MenuItem {
                                    id: forgetItem
                                    text: "Forget Network"
                                    contentItem: Text {
                                        text: forgetItem.text; color: forgetItem.hovered ? Colors.background : Colors.text
                                        font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle { color: forgetItem.hovered ? Colors.workspaceactive : "transparent"; radius: 6 }
                                    onTriggered: {
                                        netActionProcess.command = ["nmcli", "connection", "delete", modelData.ssid];
                                        netActionProcess.running = true;
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                Text {
                                    text: {
                                        if (modelData.strength > 80) return "󰤨";
                                        if (modelData.strength > 60) return "󰤥";
                                        if (modelData.strength > 40) return "󰤢";
                                        if (modelData.strength > 20) return "󰤟";
                                        return "󰤯";
                                    }
                                    color: modelData.active ? Colors.workspaceactive : Colors.text
                                    opacity: modelData.active ? 1.0 : 0.6
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: modelData.ssid || "Unknown"
                                    color: Colors.text
                                    font.pixelSize: 13
                                    font.weight: modelData.active ? Font.Bold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 75; Layout.preferredHeight: 24; radius: 6
                                    color: modelData.active ? Colors.workspaceactive : "transparent"
                                    border.color: modelData.active ? "transparent" : Colors.border; border.width: modelData.active ? 0 : 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.active ? "Disconnect" : "Connect"
                                        color: modelData.active ? Colors.background : Colors.text
                                        font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.active) {
                                                netActionProcess.command = ["nmcli", "device", "disconnect", netMenuRoot.wifiDevice.interfaceName];
                                            } else {
                                                netActionProcess.command = ["nmcli", "device", "wifi", "connect", modelData.ssid];
                                            }
                                            netActionProcess.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        visible: netMenuRoot.wifiEnabled && netMenuRoot.wifiDevice !== null && netListView.count === 0
                        text: "No networks found"
                        color: Colors.text; opacity: 0.5
                    }
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: !netMenuRoot.wifiEnabled || netMenuRoot.wifiDevice === null
                        spacing: 15
                        
                        Text { text: "󰖪"; color: Colors.text; opacity: 0.4; font.pixelSize: 42; Layout.alignment: Qt.AlignHCenter }
                        Text {
                            text: netMenuRoot.wifiDevice === null ? "No Wi-Fi adapter found" : "Wi-Fi is turned off"
                            color: Colors.text; opacity: 0.6; font.pixelSize: 13; font.weight: Font.Medium; Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // ---------------------------------
            // VIEW 2: VPN CONNECTIONS
            // ---------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: netMenuRoot.isVpnTab
                spacing: 12

                // --- VPN HEADER ---
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "VPN Connections"
                        color: Colors.text
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: "transparent"
                        
                        Text { 
                            id: vpnRefreshIcon
                            anchors.centerIn: parent
                            text: "󰑐" 
                            color: fetchVpnsProcess.running ? Colors.workspaceactive : Colors.text
                            font.pixelSize: 16 
                            
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1000
                                running: fetchVpnsProcess.running
                                onRunningChanged: { if (!running) vpnRefreshIcon.rotation = 0; }
                            }
                        }
                        
                        MouseArea { 
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!fetchVpnsProcess.running) fetchVpnsProcess.running = true; }
                        }
                    }
                }

                // --- VPN CONTENT ---
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    ListView {
                        id: vpnListView
                        anchors.fill: parent
                        spacing: 8
                        clip: true 
                        
                        model: vpnModel
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 44
                            radius: 12
                            
                            color: model.active ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15) : "transparent"
                            border.color: model.active ? Colors.workspaceactive : Colors.border
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                Text {
                                    text: "󰦝" 
                                    color: model.active ? Colors.workspaceactive : Colors.text
                                    opacity: model.active ? 1.0 : 0.6
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: model.name || "Unknown VPN"
                                    color: Colors.text
                                    font.pixelSize: 13
                                    font.weight: model.active ? Font.Bold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 75; Layout.preferredHeight: 24; radius: 6
                                    color: model.active ? Colors.workspaceactive : "transparent"
                                    border.color: model.active ? "transparent" : Colors.border; border.width: model.active ? 0 : 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.active ? "Disconnect" : "Connect"
                                        color: model.active ? Colors.background : Colors.text
                                        font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (model.active) {
                                                netActionProcess.command = ["nmcli", "connection", "down", model.name];
                                            } else {
                                                netActionProcess.command = ["nmcli", "connection", "up", model.name];
                                            }
                                            netActionProcess.running = true;
                                            
                                            // Force a fast refresh to update the UI
                                            Qt.callLater(() => {
                                                let t = Qt.createQmlObject("import QtQml; Timer {interval: 500; running: true; onTriggered: fetchVpnsProcess.running = true}", netMenuRoot);
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // NO VPNS MESSAGE
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: vpnListView.count === 0
                        spacing: 15
                        
                        Text { text: "󰦝"; color: Colors.text; opacity: 0.4; font.pixelSize: 42; Layout.alignment: Qt.AlignHCenter }
                        Text {
                            text: "No VPN connections found"
                            color: Colors.text; opacity: 0.6; font.pixelSize: 13; font.weight: Font.Medium; Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
        
        // ==========================================
        // BOTTOM TAB BAR (Wi-Fi | VPN)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            
            // 💡 THIS STOPS THE BUTTONS FROM EXPANDING UPWARDS
            Layout.preferredHeight: 36
            Layout.maximumHeight: 36 
            Layout.minimumHeight: 36
            
            spacing: 10

            // Wi-Fi Tab Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: !netMenuRoot.isVpnTab ? Colors.workspaceactive : "transparent"
                border.color: !netMenuRoot.isVpnTab ? "transparent" : Colors.border
                border.width: !netMenuRoot.isVpnTab ? 0 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "󰖩"; color: !netMenuRoot.isVpnTab ? Colors.background : Colors.text; font.pixelSize: 14 }
                    Text { text: "Wi-Fi"; color: !netMenuRoot.isVpnTab ? Colors.background : Colors.text; font.pixelSize: 12; font.weight: Font.Bold }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: netMenuRoot.isVpnTab = false
                }
            }

            // VPN Tab Button
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: netMenuRoot.isVpnTab ? Colors.workspaceactive : "transparent"
                border.color: netMenuRoot.isVpnTab ? "transparent" : Colors.border
                border.width: netMenuRoot.isVpnTab ? 0 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "󰦝"; color: netMenuRoot.isVpnTab ? Colors.background : Colors.text; font.pixelSize: 14 }
                    Text { text: "VPNs"; color: netMenuRoot.isVpnTab ? Colors.background : Colors.text; font.pixelSize: 12; font.weight: Font.Bold }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: netMenuRoot.isVpnTab = true
                }
            }
        }
    }
}