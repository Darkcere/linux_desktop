import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool isOpen: false
    signal closeRequested()
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }
    function settingRow(label, description, key) {
        return {
            label: label,
            description: description,
            key: key
        };
    }

    readonly property var settings: [
        settingRow("Bar", "Show the top bar", "enableBar"),
        settingRow("Inactive monitor bar", "Show the notch on unfocused monitors", "enableInactiveBar"),
        settingRow("OSD", "Show volume and mute overlays", "enableOsd"),
        settingRow("Wallpaper", "Render wallpaper panels", "enableWallpaper"),
        settingRow("Media", "Show media controls", "enableMedia"),
        settingRow("Visualizer", "Run the cava visualizer", "enableVisualizer"),
        settingRow("Notifications", "Receive notification events", "enableNotifications"),
        settingRow("Notification popups", "Show transient notification popups", "enableNotificationPopups"),
        settingRow("System tray", "Show tray icons", "enableTray"),
        settingRow("System stats card", "Show and poll CPU, RAM, disk, and GPU", "enableSystemStats"),
        settingRow("Network monitor", "Poll network traffic in the dashboard", "enableNetworkMonitor"),
        settingRow("Dashboard calendar", "Show the dashboard calendar", "enableDashboardCalendar"),
        settingRow("Dashboard quick settings", "Show Wi-Fi, Bluetooth, and power controls", "enableQuickSettings"),
        settingRow("Bluetooth", "Show Bluetooth controls", "enableBluetooth"),
        settingRow("Audio protection", "Limit sudden volume jumps", "enableAudioProtection")
    ]
 
    function settingValue(key) {
        return SettingsService[key];
    }

    function setSetting(key, value) {
        SettingsService[key] = value;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Feature Settings"
                color: Colors.text
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

           
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.color: Colors.border
            border.width: 1
            radius: 8

            ListView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: root.settings
                spacing: 4

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 54
                    color: "transparent"
                    radius: 6

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: toggle.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: Colors.text
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            text: modelData.description
                            color: Colors.text
                            opacity: 0.6
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Switch {
                        id: toggle
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.settingValue(modelData.key)
                        onToggled: root.setSetting(modelData.key, checked)
                    }
                }
            }
        }
    }
}
