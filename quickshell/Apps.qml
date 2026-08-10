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

    // --- REFRESH APPS ON OPEN ---
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

    Shortcut {
        sequence: "Ctrl+R"
        enabled: launcherWindow.isOpen
        onActivated: {
            console.log("QUICKSHELL: Manually re-scanning application entries...")
            fetchAppsProcess.running = true
        }
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

    function sortApps() {
        launcherWindow.allAppsData.sort((a, b) => {
            let countA = launcherWindow.usageCounts[a.name] || 0;
            let countB = launcherWindow.usageCounts[b.name] || 0;
            if (countB !== countA) return countB - countA; 
            return a.name.localeCompare(b.name);
        });
    }
 
    // --- SAFE MATH EVALUATOR ---
    function tryEvaluateMath(query) {
        let q = query.trim();
        let isExplicit = q.startsWith("=");
        if (isExplicit) {
            q = q.substring(1).trim();
        }

        if (!q) return null;

        // Require at least one number AND (an operator OR a math function) when not prefixed with '='
        let hasOperatorOrFunc = /[+\-*/^%]|\b(sqrt|sin|cos|tan|log|abs|round|floor|ceil|pow|min|max|PI|E)\b/i.test(q);
        if (!isExplicit && (!/\d/.test(q) || !hasOperatorOrFunc)) {
            return null;
        }

        // Convert friendly syntax ('^' -> '**', 'pi' -> 'PI')
        let expr = q.replace(/\^/g, "**").replace(/\bpi\b/gi, "PI");

        // Safety check: strip all allowed math tokens. If any text remains, it's not a pure math expression.
        let sanitized = expr
            .replace(/\b(sqrt|sin|cos|tan|log|abs|round|floor|ceil|pow|min|max|PI|E)\b/g, "")
            .replace(/[0-9+\-*/%.() \t\n\r]/g, "");

        if (sanitized.length > 0) {
            return null;
        }

        try {
            let fn = new Function(
                "sqrt", "sin", "cos", "tan", "log", "abs", "round", "floor", "ceil", "pow", "min", "max", "PI", "E",
                "return (" + expr + ");"
            );
            
            let result = fn(
                Math.sqrt, Math.sin, Math.cos, Math.tan, Math.log, Math.abs, Math.round, Math.floor, Math.ceil, Math.pow, Math.min, Math.max, Math.PI, Math.E
            );

            if (typeof result === "number" && !isNaN(result) && isFinite(result)) {
                // Clean up floating-point precision errors (e.g. 0.1 + 0.2 -> 0.3)
                let cleanResult = Number(Math.round(result + 'e10') + 'e-10');
                return {
                    name: "=  " + cleanResult,
                    expression: q + " = " + cleanResult,
                    command: String(cleanResult),
                    icon: "accessories-calculator",
                    isMath: true,
                    resultValue: String(cleanResult)
                };
            }
        } catch (e) {
            // Silently ignore incomplete expressions while typing (e.g., "sqrt(")
            return null;
        }
        return null;
    }

    function launchApp(entry) {
        if (!entry) return;
        
        // --- HANDLE MATH RESULT (COPY TO CLIPBOARD) ---
        if (entry.isMath) {
            console.debug("Copying math result to clipboard: " + entry.resultValue);
            launcherWindow.closeRequested();
            
            // Works across Wayland (wl-copy) and X11 (xclip)
            Quickshell.execDetached({
                command: ["sh", "-c", "printf '%s' '" + entry.resultValue + "' | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null)"]
            });
            return;
        }

        let counts = launcherWindow.usageCounts;
        counts[entry.name] = (counts[entry.name] || 0) + 1;
        launcherWindow.usageCounts = counts;
        appSettings.usageData = JSON.stringify(counts); 
        
        sortApps();
        launcherWindow.closeRequested();
        console.debug("Executing -> Name: " + entry.name + " | Dir: " + entry.workingDirectory + " | Uses: " + counts[entry.name]);
        
        let cmdArgs = (entry.command || entry.name).split(" ").filter(Boolean);
        
        if (entry.terminal) {
            cmdArgs.unshift("foot");
        }

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
            "seen_names = set()\n" +
            "\n" +
            "def process_files(file_list):\n" +
            "    for p in file_list:\n" +
            "        try:\n" +
            "            with open(p, 'r', encoding='utf-8') as f:\n" +
            "                app = {'name':'', 'command':'', 'icon':'', 'workingDirectory':'', 'nodisplay':False, 'terminal':False}\n" +
            "                for line in f:\n" +
            "                    if line.startswith('Name=') and not app['name']: app['name'] = line[5:].strip().replace('\"', '')\n" +
            "                    elif line.startswith('Exec=') and not app['command']: app['command'] = line[5:].split(' %')[0].split(' @@')[0].strip().replace('\"', '')\n" +
            "                    elif line.startswith('Icon=') and not app['icon']: app['icon'] = line[5:].strip().replace('\"', '')\n" +
            "                    elif line.startswith('Path=') and not app['workingDirectory']: app['workingDirectory'] = line[5:].strip().replace('\"', '')\n" +
            "                    elif line.startswith('NoDisplay=') and line[10:].strip().lower() == 'true': app['nodisplay'] = True\n" +
            "                    elif line.startswith('Terminal=') and line[9:].strip().lower() == 'true': app['terminal'] = True\n" +
            "                if app['name'] and app['command'] and not app['nodisplay'] and app['name'] not in seen_names:\n" +
            "                    del app['nodisplay']\n" +
            "                    apps.append(app)\n" +
            "                    seen_names.add(app['name'])\n" +
            "        except: pass\n" +
            "\n" +
            "# 1. Scan System Paths (Priority 1)\n" +
            "system_paths = glob.glob('/usr/share/applications/*.desktop') + \\\n" +
            "               glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop')) + \\\n" +
            "               glob.glob('/var/lib/flatpak/exports/share/applications/*.desktop') + \\\n" +
            "               glob.glob(os.path.expanduser('~/.local/share/flatpak/exports/share/applications/*.desktop'))\n" +
            "process_files(system_paths)\n" +
            "\n" +
            "# 2. Scan Desktop Path (Priority 2 - only if not found in system)\n" +
            "desktop_paths = glob.glob(os.path.expanduser('~/Desktop/*.desktop'))\n" +
            "process_files(desktop_paths)\n" +
            "\n" +
            "print(json.dumps(apps))"
        ]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcherWindow.allAppsData = JSON.parse(text);
                    launcherWindow.sortApps(); 
                    filterApps(searchInput.text);
                } catch(e) {
                    console.log("Failed to parse apps: " + e);
                }
            }
        }
    }

    function filterApps(query) {
        launcherWindow.selectedIndex = 0; 
        
        if (query.startsWith(launcherWindow.actionPrefix)) {
            launcherWindow.currentApps = [];
            return; 
        }

        let lowerQuery = query.toLowerCase();
        
        // 1. Check if the input is a valid math expression
        let mathResult = tryEvaluateMath(query);
        let results = [];
        
        if (mathResult) {
            results.push(mathResult);
        }

        let nameStartsWith = [];
        let cmdStartsWith = [];
        let nameContains = [];
        let cmdContains = [];

        for (let i = 0; i < allAppsData.length; i++) {
            let app = allAppsData[i];
            let nameLower = app.name.toLowerCase();
            let cmdLower = (app.command || "").toLowerCase();
            
            if (nameLower.startsWith(lowerQuery)) {
                nameStartsWith.push(app);
            } else if (cmdLower.startsWith(lowerQuery)) {
                cmdStartsWith.push(app);
            } else if (nameLower.includes(lowerQuery)) {
                nameContains.push(app);
            } else if (cmdLower.includes(lowerQuery)) {
                cmdContains.push(app);
            }
        }
        
        // 2. Prepend math result at the very top of the list
        launcherWindow.currentApps = results.concat(nameStartsWith, cmdStartsWith, nameContains, cmdContains); 
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

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
                color: Colors.workspaceactive 
                font.pixelSize: 16
                focus: true 
                
                Text {
                    text: "Search Apps or Math (e.g. 5+10*2, sqrt(64))..."
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
                    if (launcherWindow.currentApps.length > 0) {
                        launcherWindow.selectedIndex = Math.min(launcherWindow.selectedIndex + 1, launcherWindow.currentApps.length - 1);
                        appsList.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                    }
                    event.accepted = true;
                }
                
                Keys.onUpPressed: (event) => {
                    if (launcherWindow.currentApps.length > 0) {
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
            model: launcherWindow.currentApps 
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
                            source: modelData.icon ? ("image://icon/" + modelData.icon) : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 36
                            sourceSize.height: 36
                            onStatusChanged: { if (status === Image.Error) visible = false; }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.border 
                            radius: 8 
                            visible: !appIconImg.visible
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.isMath ? "=" : (modelData.name ? modelData.name[0] : "?")
                                color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.background : Colors.text
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }

                    // Main Label (App Name or Math Result)
                    Text {
                        id: mainTextLabel
                        text: modelData.name
                        color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.background : Colors.text
                        font.pixelSize: modelData.isMath ? 18 : 15
                        font.bold: (appMouseArea.containsMouse || appsList.currentIndex === index) || modelData.isMath
                        anchors.left: iconContainer.right
                        anchors.leftMargin: 15
                        anchors.right: subtitleText.visible ? subtitleText.left : parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }

                    // Helper Text for Math Results ("Press Enter to copy")
                    Text {
                        id: subtitleText
                        text: "Copy to clipboard"
                        visible: Boolean(modelData.isMath)
                        color: (appMouseArea.containsMouse || appsList.currentIndex === index) ? Colors.background : Colors.text
                        opacity: 0.6
                        font.pixelSize: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        id: appMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            launcherWindow.launchApp(modelData);
                        }
                    }
                }
            }
        }
    }
}