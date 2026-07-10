import Quickshell
import QtQuick
import QtCore 
import Quickshell.Io 

Item {
    id: launcherWindow
    
    property bool isOpen: false
    signal closeRequested()

    Component.onCompleted: {
        fetchAppsProcess.running = true
    }
    
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            filterApps("")
            focusTimer.start()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: launcherWindow.closeRequested()
    }

    property var allAppsData: [] 
    property var currentApps: [] 
    property int selectedIndex: 0
    
    Settings {
        id: appSettings
        category: "CaelestiaLauncher"
        property string usageData: "{}" 
    }
    
    property var usageCounts: JSON.parse(appSettings.usageData || "{}")
    property string actionPrefix: ">"

    ListModel { id: appModel }

    function sortApps() {
        launcherWindow.allAppsData.sort((a, b) => {
            let countA = launcherWindow.usageCounts[a.name] || 0;
            let countB = launcherWindow.usageCounts[b.name] || 0;
            if (countB !== countA) return countB - countA; 
            return a.name.localeCompare(b.name);
        });
    }

    function launchApp(entry) {
        if (!entry) return;
        
        let counts = launcherWindow.usageCounts;
        counts[entry.name] = (counts[entry.name] || 0) + 1;
        launcherWindow.usageCounts = counts;
        appSettings.usageData = JSON.stringify(counts); 
        
        sortApps();
        launcherWindow.closeRequested();
        console.debug("Executing -> Name: " + entry.name + " | Dir: " + entry.workingDirectory + " | Uses: " + counts[entry.name]);
        
        let cmdArgs = (entry.command || entry.name).split(" ").filter(Boolean);
        Quickshell.execDetached({ 
            command: cmdArgs, 
            workingDirectory: entry.workingDirectory || "/"
        });
    }

    Process {
        id: fetchAppsProcess
        command: [
            "python3", "-c",
            "import os, json, glob\n" +
            "apps = []\n" +
            "paths = glob.glob('/usr/share/applications/*.desktop') + \\\n" +
            "        glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop')) + \\\n" +
            "        glob.glob('/var/lib/flatpak/exports/share/applications/*.desktop') + \\\n" +
            "        glob.glob(os.path.expanduser('~/.local/share/flatpak/exports/share/applications/*.desktop'))\n" +
            "for p in paths:\n" +
            "    try:\n" +
            "        with open(p, 'r', encoding='utf-8') as f:\n" +
            "            app = {'name':'', 'command':'', 'icon':'', 'workingDirectory':'', 'nodisplay':False}\n" +
            "            for line in f:\n" +
            "                if line.startswith('Name=') and not app['name']: app['name'] = line[5:].strip().replace('\"', '')\n" +
            "                elif line.startswith('Exec=') and not app['command']: app['command'] = line[5:].split(' %')[0].split(' @@')[0].strip().replace('\"', '')\n" +
            "                elif line.startswith('Icon=') and not app['icon']: app['icon'] = line[5:].strip().replace('\"', '')\n" +
            "                elif line.startswith('Path=') and not app['workingDirectory']: app['workingDirectory'] = line[5:].strip().replace('\"', '')\n" +
            "                elif line.startswith('NoDisplay=') and line[10:].strip().lower() == 'true': app['nodisplay'] = True\n" +
            "            if app['name'] and app['command'] and not app['nodisplay']:\n" +
            "                del app['nodisplay']\n" +
            "                apps.append(app)\n" +
            "    except: pass\n" +
            "print(json.dumps(apps))"
        ]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcherWindow.allAppsData = JSON.parse(text);
                    launcherWindow.sortApps(); 
                    filterApps("");
                } catch(e) {
                    console.log("Failed to parse apps: " + e);
                }
            }
        }
    }

    function filterApps(query) {
        appModel.clear();
        let tempArr = [];
        launcherWindow.selectedIndex = 0; 
        
        if (query.startsWith(launcherWindow.actionPrefix)) {
            launcherWindow.currentApps = [];
            return; 
        }

        let lowerQuery = query.toLowerCase();
        for (let i = 0; i < allAppsData.length; i++) {
            if (allAppsData[i].name.toLowerCase().includes(lowerQuery)) {
                tempArr.push(allAppsData[i]); 
                appModel.append({
                    "name": allAppsData[i].name,
                    "command": allAppsData[i].command,
                    "icon": allAppsData[i].icon,
                    "workingDirectory": allAppsData[i].workingDirectory
                });
            }
        }
        launcherWindow.currentApps = tempArr; 
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // --- MATCHING SEARCH BAR STYLE ---
        Rectangle {
            width: parent.width
            height: 45
            color: Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1) 
            radius: 8
            border.color: Colors.border
            border.width: 2

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.workspaceactive // Changed to match wallpaper picker
                font.pixelSize: 16
                focus: true 
                
                // --- PROPER PLACEHOLDER ---
                Text {
                    text: "Search Apps..."
                    color: Colors.workspaceactive
                    opacity: 0.4
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !parent.text
                }
                
                onTextChanged: launcherWindow.filterApps(text)
                
                Keys.onEscapePressed: (event) => {
                    event.accepted = true;
                    launcherWindow.closeRequested();
                }
                
                Keys.onDownPressed: (event) => {
                    if (appModel.count > 0) {
                        launcherWindow.selectedIndex = Math.min(launcherWindow.selectedIndex + 1, appModel.count - 1);
                        appsList.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                
                Keys.onUpPressed: (event) => {
                    if (appModel.count > 0) {
                        launcherWindow.selectedIndex = Math.max(launcherWindow.selectedIndex - 1, 0);
                        appsList.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                
                Keys.onReturnPressed: (event) => {
                    event.accepted = true;
                    let query = text.trim();

                    if (query.startsWith(launcherWindow.actionPrefix)) {
                        let rawAction = query.substring(launcherWindow.actionPrefix.length).trim();
                        let cmdArgs = rawAction ? rawAction.split(" ") : []; 
                        if (cmdArgs.length > 0) {
                            launcherWindow.closeRequested();
                            Quickshell.execDetached({ command: cmdArgs });
                        }
                        return;
                    }

                    if (launcherWindow.selectedIndex >= 0 && launcherWindow.selectedIndex < launcherWindow.currentApps.length) {
                        let entry = launcherWindow.currentApps[launcherWindow.selectedIndex];
                        launcherWindow.launchApp(entry);
                    }
                }
            }
        }

        ListView {
            id: appsList
            width: parent.width
            height: parent.height - 60 
            clip: true
            model: appModel 
            currentIndex: launcherWindow.selectedIndex
            spacing: 5

            opacity: searchInput.text.startsWith(launcherWindow.actionPrefix) ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            delegate: Item {
                width: appsList.width
                height: 54

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    
                    // --- HIGH CONTRAST SELECTION HIGHLIGHT ---
                    color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.workspaceactive : "transparent"
                    radius: 8
                    
                    Item {
                        id: iconContainer
                        width: 36
                        height: 36
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIconImg
                            anchors.fill: parent
                            source: model.icon ? ("image://icon/" + model.icon) : ""
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: { if (status === Image.Error) visible = false; }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.border 
                            radius: 8 
                            visible: !appIconImg.visible
                            
                            Text {
                                anchors.centerIn: parent
                                text: model.name ? model.name[0] : "?" 
                                // --- INVERT FALLBACK TEXT ON HOVER ---
                                color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.background : Colors.text
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        text: model.name
                        // --- INVERT LIST TEXT ON HOVER ---
                        color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.background : Colors.text
                        font.pixelSize: 15
                        font.bold: (appMouseArea.containsMouse || appsList.currentIndex === index)
                        anchors.left: iconContainer.right
                        anchors.leftMargin: 15
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: appMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            if (index >= 0 && index < launcherWindow.currentApps.length) {
                                let entry = launcherWindow.currentApps[index];
                                launcherWindow.launchApp(entry);
                            }
                        }
                    }
                }
            }
        }
    }
}