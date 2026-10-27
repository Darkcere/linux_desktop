import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal closeRequested()
    property string searchText: ""
    property string selectedSection: "Interface"
    readonly property var sections: ["Interface", "Dashboard", "Modules", "Notifications & Safety"]

    function section(title, description) {
        return { kind: "section", label: title, description: description };
    }

    function setting(label, description, key) {
        return { kind: "setting", label: label, description: description, key: key };
    }

    readonly property var rows: [
        section("Interface", "Control what stays visible around your desktop"),
        setting("Active monitor bar", "Show the main top bar", "enableBar"),
        setting("Inactive monitor bar", "Show the notch on unfocused monitors", "enableInactiveBar"),
        setting("OSD overlays", "Show volume and mute feedback", "enableOsd"),
        setting("Wallpaper", "Render wallpaper panels on every screen", "enableWallpaper"),
        setting("Media controls", "Show media controls in the shell", "enableMedia"),
        setting("Cava visualizer", "Keep the audio visualizer process running", "enableVisualizer"),
        setting("System tray", "Show tray icons in the bar", "enableTray"),
        section("Dashboard", "Choose which dashboard panels stay active"),
        setting("System stats card", "Show and poll CPU, GPU, RAM, and disk", "enableSystemStats"),
        setting("Network monitor", "Poll and graph network traffic", "enableNetworkMonitor"),
        setting("Quick settings", "Show Wi-Fi, Bluetooth, and power controls", "enableQuickSettings"),
        setting("Calendar", "Show the dashboard calendar", "enableDashboardCalendar"),
        setting("Bluetooth controls", "Allow Bluetooth controls in the dashboard", "enableBluetooth"),
        section("Modules", "Choose which shell tools are available"),
        setting("Night light", "Allow night-light controls", "enableNightLight"),
        setting("Launcher", "Allow the application launcher", "enableLauncher"),
        setting("Clipboard", "Allow clipboard history", "enableClipboard"),
        setting("Tools", "Allow utility tools and scripts", "enableTools"),
        setting("Power menu", "Allow suspend, reboot, and power actions", "enablePowerMenu"),
        setting("Wallpaper picker", "Allow wallpaper selection", "enableWallpaperPicker"),
        setting("Audio menu", "Allow audio device controls", "enableAudioMenu"),
        setting("Lock screen", "Allow the custom lock screen", "enableLockScreen"),
        section("Notifications & Safety", "Tune notification behavior and background work"),
        setting("Notifications", "Receive and keep notification history", "enableNotifications"),
        setting("Notification popups", "Show transient notification popups", "enableNotificationPopups")
    ]

    function value(key) { return SettingsService[key]; }
    function setValue(key, nextValue) { SettingsService[key] = nextValue; }

    function filteredRows() {
        const query = searchText.trim().toLowerCase();
        const result = [];
        let selected = false;
        rows.forEach(row => {
            if (row.kind === "section") {
                selected = row.label === selectedSection;
                if (selected) result.push(row);
            } else if (selected && (query === "" || row.label.toLowerCase().includes(query) || row.description.toLowerCase().includes(query))) {
                result.push(row);
            }
        });
        return result;
    }

    function enabledCount() {
        return rows.filter(row => row.kind === "setting" && value(row.key)).length;
    }

    function resetSettings() {
        rows.forEach(row => {
            if (row.kind === "setting") SettingsService[row.key] = true;
        });
    }

    Shortcut { sequence: "Escape"; onActivated: root.closeRequested() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 184
            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.025)
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: Colors.workspaceactive
                        Text { anchors.centerIn: parent; text: "Q"; color: Colors.background; font.pixelSize: 20; font.bold: true }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Quickshell"; color: Colors.text; font.bold: true; font.pixelSize: 13 }
                        Text { text: "Settings"; color: Colors.text; opacity: 0.55; font.pixelSize: 10 }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; opacity: 0.45 }
                Text { text: "SETTINGS"; color: Colors.text; opacity: 0.45; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.sections
                    spacing: 4
                    clip: true
                    delegate: Rectangle {
                        required property string modelData
                        width: ListView.view.width
                        height: 38
                        radius: 8
                        color: root.selectedSection === modelData ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.9) : (navMouse.containsMouse ? Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.06) : "transparent")
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: modelData; color: root.selectedSection === modelData ? Colors.background : Colors.text
                            font.pixelSize: 12; font.bold: root.selectedSection === modelData
                        }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedSection = modelData
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; opacity: 0.45 }
                Text { text: root.enabledCount() + " of " + (root.rows.length - root.sections.length) + " enabled"; color: Colors.workspaceactive; font.pixelSize: 11 }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: root.selectedSection; color: Colors.text; font.pixelSize: 25; font.bold: true }
                        Text { text: "Shape the shell around the way you work."; color: Colors.text; opacity: 0.58; font.pixelSize: 12 }
                    }
                    Button { text: "Reset"; onClicked: root.resetSettings() }
                    ToolButton { text: "×"; font.pixelSize: 24; onClicked: root.closeRequested() }
                }

                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Search in " + root.selectedSection
                    text: root.searchText
                    onTextChanged: root.searchText = text
                    selectByMouse: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.025)
                    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.7)
                    border.width: 1
                    radius: 10
                    clip: true

                    ListView {
                        id: settingsList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 4
                        model: root.filteredRows()
                        ScrollBar.vertical: ScrollBar { }

                        delegate: Item {
                            required property var modelData
                            width: settingsList.width - 12
                            height: modelData.kind === "section" ? 46 : 68

                            Text {
                                visible: modelData.kind === "section"
                                anchors.left: parent.left; anchors.leftMargin: 12
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                                text: modelData.description; color: Colors.text; opacity: 0.5; font.pixelSize: 11
                            }

                            Rectangle {
                                visible: modelData.kind === "setting"
                                anchors.fill: parent
                                color: rowMouse.containsMouse ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.12) : "transparent"
                                radius: 8

                                Column {
                                    anchors.left: parent.left; anchors.leftMargin: 14
                                    anchors.right: switchControl.left; anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text { text: modelData.label; color: Colors.text; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                    Text { text: modelData.description; color: Colors.text; opacity: 0.58; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                                }

                                Rectangle {
                                    id: switchControl
                                    property bool checked: root.value(modelData.key)
                                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                    width: 46; height: 26; radius: 13
                                    color: checked ? Colors.workspaceactive : Colors.border
                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: switchControl.checked ? parent.width - width - 3 : 3
                                        color: switchControl.checked ? Colors.background : Colors.text
                                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    }
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setValue(modelData.key, !switchControl.checked) }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
