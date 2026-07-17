import Quickshell
import QtQuick
import QtQuick.Controls 
import QtCore 
import Quickshell.Io 
import Qt5Compat.GraphicalEffects

Item {
    id: pickerWindow
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }
    property bool isOpen: false
    signal closeRequested()

    signal wallpaperSelected(string path)

    // 💡 THE FIX: Instant C++ Cache
    Settings {
        id: wallpaperSettings
        category: "CaelestiaWallpapers"
        property string cachedWallpapers: "[]"
        property string cachedActive: ""
    }

    property var allWallpapersData: JSON.parse(wallpaperSettings.cachedWallpapers === "" ? "[]" : wallpaperSettings.cachedWallpapers)
    property var currentWallpapers: allWallpapersData
    property int selectedIndex: 0
    
    property string activeWallpaperPath: wallpaperSettings.cachedActive
    property var stagedRandomEntry: null 

    Timer {
        id: applyThemeTimer
        interval: 400 
        property string pendingCmd: ""
        onTriggered: {
            console.debug("Executing delayed theme update...");
            Quickshell.execDetached({ command: ["bash", "-c", pendingCmd] });
        }
    }

    Component.onCompleted: {
        fetchWallpapersProcess.running = true
        if (allWallpapersData.length > 0) {
            pickerWindow.rollRandomWallpaper();
        }
    }
    
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }

    Timer {
        id: searchDebounce
        interval: 200
        onTriggered: pickerWindow.filterWallpapers(searchInput.text)
    }
    
    Timer {
        id: loadDelayTimer
        interval: 350 
        onTriggered: filterWallpapers(searchInput.text)
    }

    onIsOpenChanged: {
        if (isOpen) {
            focusTimer.start()
            loadDelayTimer.start()
            
            if (searchInput.text === "" && currentWallpapers.length === 0 && allWallpapersData.length > 0) {
                 filterWallpapers("")
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+R"
        enabled: pickerWindow.isOpen
        onActivated: {
            console.log("QUICKSHELL: Manually refreshing wallpaper directory...")
            fetchWallpapersProcess.running = true
        }
    }

    function rollRandomWallpaper() {
        let actualWallpapers = pickerWindow.allWallpapersData.filter(w => w.path !== "random_trigger");
        if (actualWallpapers.length > 0) {
            pickerWindow.stagedRandomEntry = actualWallpapers[Math.floor(Math.random() * actualWallpapers.length)];
        }
    }

    function setWallpaper(entry) {
        if (!entry) return;
        
        let targetPath = entry.rawPath !== undefined ? entry.rawPath : entry.path;
        
        if (targetPath === "random_trigger") {
            if (!pickerWindow.stagedRandomEntry) return; 
            
            // 💡 THE FIX: Use rawPath so the bash symlink works!
            targetPath = pickerWindow.stagedRandomEntry.rawPath;
        }
        
        pickerWindow.activeWallpaperPath = targetPath;
        wallpaperSettings.cachedActive = targetPath; // 💡 Update the cache!
        pickerWindow.wallpaperSelected(targetPath);
        
        let bashCmd = `
            echo "${targetPath}" > "$HOME/.current_wall_path"
            ln -sf "${targetPath}" "$HOME/.current.wall"
            hyprctl dispatch global quickshell:updateWallpaper
        `;
        
        Quickshell.execDetached({ command: ["bash", "-c", bashCmd] });
        pickerWindow.closeRequested();
        
        if (entry.rawPath === "random_trigger") {
            pickerWindow.rollRandomWallpaper();
        }
    }

    Process {
        id: fetchWallpapersProcess
        command: [
            "python3", "-c",
            "import os, json, random\n" +
            "wps = []\n" +
            "current_wall = ''\n" +
            "wp_dir = os.path.expanduser('~/Pictures/Wallpapers')\n" +
            "link_path = os.path.expanduser('~/.current.wall')\n" +
            "\n" +
            "for root, dirs, files in os.walk(wp_dir):\n" +
            "    if '.git' in dirs: dirs.remove('.git')\n" +
            "    for f in files:\n" +
            "        if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.gif')):\n" +
            "            path = os.path.join(root, f)\n" +
            "            rel = os.path.relpath(path, wp_dir)\n" +
            "            subfolder = os.path.dirname(rel)\n" +
            "            if not subfolder: subfolder = 'Main Folder'\n" +
            "            name = os.path.basename(path).rsplit('.', 1)[0]\n" +
            "            # Pre-calculate the Qt paths to save QML processing later\n" +
            "            wps.append({'name': name, 'path': 'file://' + path, 'rawPath': path, 'subfolder': subfolder})\n" +
            "\n" +
            "if os.path.exists(link_path):\n" +
            "    current_wall = os.path.realpath(link_path)\n" +
            "elif wps:\n" +
            "    random_wp = random.choice(wps)\n" +
            "    current_wall = random_wp['rawPath']\n" +
            "    os.symlink(current_wall, link_path)\n" +
            "\n" +
            "print(json.dumps({'current': current_wall, 'wallpapers': wps}))"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    let fileCountChanged = (pickerWindow.allWallpapersData.length === 0 || 
                                          pickerWindow.allWallpapersData.length !== (data.wallpapers.length + 1));
                    let activeChanged = (data.current && data.current !== "" && 
                                       data.current !== pickerWindow.activeWallpaperPath);

                    let freshArray = data.wallpapers;
                    freshArray.sort((a, b) => a.name.localeCompare(b.name));
                    
                    freshArray.unshift({
                        "name": "Random Wallpaper",
                        "path": "random_trigger",
                        "rawPath": "random_trigger",
                        "subfolder": "Surprise Me"
                    });
                    
                    pickerWindow.allWallpapersData = freshArray;
                    
                    // 💡 THE FIX: Save the parsed array to the native config file
                    wallpaperSettings.cachedWallpapers = JSON.stringify(freshArray);
                    
                    if (activeChanged) {
                        pickerWindow.activeWallpaperPath = data.current;
                        wallpaperSettings.cachedActive = data.current;
                    }

                    if (fileCountChanged || currentWallpapers.length === 0) {
                        if (currentWallpapers.length === 0) {
                            pickerWindow.rollRandomWallpaper(); 
                        }
                        filterWallpapers(searchInput.text);
                    }
                } catch(e) {
                    console.log("Failed to load wallpapers: " + e);
                }
            }
        }
    }

    // 💡 THE FIX: Native JS array filtering instead of ListModel building!
    function filterWallpapers(query) {
        let lowerQuery = query.toLowerCase();
        
        if (lowerQuery === "") {
            pickerWindow.currentWallpapers = pickerWindow.allWallpapersData;
        } else {
            pickerWindow.currentWallpapers = pickerWindow.allWallpapersData.filter(
                item => item.name.toLowerCase().includes(lowerQuery) || 
                        item.subfolder.toLowerCase().includes(lowerQuery)
            );
        }
        
        pickerWindow.selectedIndex = 0;
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
                    text: "Search Wallpapers... (Ctrl+R to refresh)"
                    color: Colors.workspaceactive
                    opacity: 0.4
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !parent.text
                }
                
                onTextChanged: searchDebounce.restart()
                
                Keys.onDownPressed: (event) => {
                    event.accepted = true;
                    if (pickerWindow.currentWallpapers.length > 0) {
                        pickerWindow.selectedIndex = Math.min(pickerWindow.selectedIndex + 1, pickerWindow.currentWallpapers.length - 1);
                        wallpaperGrid.positionViewAtIndex(pickerWindow.selectedIndex, GridView.Contain);
                    }
                }
                Keys.onUpPressed: (event) => {
                    event.accepted = true;
                    if (pickerWindow.currentWallpapers.length > 0) {
                        pickerWindow.selectedIndex = Math.max(pickerWindow.selectedIndex - 1, 0);
                        wallpaperGrid.positionViewAtIndex(pickerWindow.selectedIndex, GridView.Contain);
                    }
                }
                Keys.onReturnPressed: (event) => {
                    event.accepted = true;
                    if (pickerWindow.selectedIndex >= 0 && pickerWindow.selectedIndex < pickerWindow.currentWallpapers.length) {
                        pickerWindow.setWallpaper(pickerWindow.currentWallpapers[pickerWindow.selectedIndex]);
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: parent.height - 130 
            spacing: 15

            GridView {
                id: wallpaperGrid
                width: (parent.width * 0.6) - 7.5 
                height: parent.height 
                clip: true
                
                // 💡 THE FIX: Bind directly to the JS array
                model: pickerWindow.currentWallpapers 
                currentIndex: pickerWindow.selectedIndex
                
                cellWidth: width / 3
                cellHeight: 120 
                flickableDirection: Flickable.VerticalFlick 

                cacheBuffer: 100
                displayMarginBeginning: 0
                displayMarginEnd: 0
                
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton 
                    onWheel: (wheel) => {
                        let maxScroll = Math.max(0, wallpaperGrid.contentHeight - wallpaperGrid.height);
                        let newY = wallpaperGrid.contentY - (wheel.angleDelta.y * 1.7);
                        wallpaperGrid.contentY = Math.max(0, Math.min(newY, maxScroll));
                        wheel.accepted = true; 
                    }
                }

                ScrollBar.vertical: ScrollBar { 
                    active: true 
                    width: 8
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        
                        color: (wpMouseArea.containsMouse || wallpaperGrid.currentIndex === index) ? Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.2) : "transparent"
                        radius: 8
                        
                        Rectangle {
                            id: thumbMask
                            anchors.fill: parent
                            radius: 8
                            visible: false
                        }
                        
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            
                            // 💡 THE FIX: Just use .path directly, no "file://" prefix needed!
                            source: modelData.rawPath === "random_trigger" 
                                ? (pickerWindow.stagedRandomEntry ? pickerWindow.stagedRandomEntry.path : "")
                                : modelData.path
                            
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true 
                            cache: true 
                            
                            sourceSize.width: 128
                            sourceSize.height: 128
                            
                            visible: false
                        }
                        
                        OpacityMask {
                            anchors.fill: parent
                            source: thumbImg
                            maskSource: thumbMask
                            opacity: (wpMouseArea.containsMouse || wallpaperGrid.currentIndex === index || modelData.rawPath === pickerWindow.activeWallpaperPath) ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            color: Colors.background
                            opacity: 0.65
                            visible: modelData.rawPath === "random_trigger"
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🎲"
                            font.pixelSize: 42
                            visible: modelData.rawPath === "random_trigger"
                            opacity: (wpMouseArea.containsMouse || wallpaperGrid.currentIndex === index) ? 1.0 : 0.7
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: (modelData.rawPath === pickerWindow.activeWallpaperPath || wpMouseArea.containsMouse || wallpaperGrid.currentIndex === index) ? Colors.workspaceactive : "transparent"
                            border.width: 2
                            radius: 8 
                        }
                        
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 50
                            height: 20
                            radius: 4
                            color: Colors.workspaceactive
                            visible: modelData.rawPath === pickerWindow.activeWallpaperPath
                            
                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                color: Colors.background
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                        
                        MouseArea {
                            id: wpMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (index >= 0 && index < pickerWindow.currentWallpapers.length) {
                                    pickerWindow.setWallpaper(pickerWindow.currentWallpapers[index]);
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width * 0.4) - 7.5
                height: parent.height
                color: "transparent"
                radius: 8
                border.color: Colors.border
                border.width: 2
                visible: pickerWindow.currentWallpapers.length > 0

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10
                    
                    Rectangle {
                        width: parent.width
                        height: parent.height - 70 
                        color: "transparent"

                        Rectangle {
                            id: largeMask
                            anchors.fill: parent
                            radius: 6
                            visible: false
                        }

                        Image {
                            id: largeImg
                            anchors.fill: parent
                            source: {
                                if (pickerWindow.currentWallpapers.length === 0 || pickerWindow.selectedIndex < 0) return "";
                                
                                let item = pickerWindow.currentWallpapers[pickerWindow.selectedIndex];
                                if (!item) return "";
                                
                                if (item.rawPath === "random_trigger") {
                                    // 💡 THE FIX: Just use .path directly!
                                    return pickerWindow.stagedRandomEntry ? pickerWindow.stagedRandomEntry.path : "";
                                }
                                return item.path;
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            
                            sourceSize.width: 256
                            sourceSize.height: 256
                            
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: largeImg
                            maskSource: largeMask
                            visible: largeImg.source !== ""
                        }
                    }
                    
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            width: parent.width
                            text: {
                                if (pickerWindow.currentWallpapers.length === 0 || pickerWindow.selectedIndex < 0) return "";
                                let item = pickerWindow.currentWallpapers[pickerWindow.selectedIndex];
                                if (!item) return "";
                                
                                if (item.rawPath === "random_trigger") {
                                    return pickerWindow.stagedRandomEntry ? "🎲 " + pickerWindow.stagedRandomEntry.name : "Random Wallpaper";
                                }
                                return item.name;
                            }
                            color: Colors.workspaceactive
                            font.pixelSize: 20
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            width: parent.width
                            text: {
                                if (pickerWindow.currentWallpapers.length === 0 || pickerWindow.selectedIndex < 0) return "";
                                let item = pickerWindow.currentWallpapers[pickerWindow.selectedIndex];
                                if (!item) return "";
                                
                                if (item.rawPath === "random_trigger") {
                                    return pickerWindow.stagedRandomEntry ? pickerWindow.stagedRandomEntry.subfolder : "Surprise Me";
                                }
                                return item.subfolder;
                            }
                            color: Colors.workspace
                            opacity: 0.6
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight 
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 55
            color: Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1) 
            border.color: Colors.border
            border.width: 2 
            radius: 8
            
            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12
                
                Rectangle {
                    width: 65
                    height: 39
                    color: "transparent"
                    
                    Rectangle {
                        id: bottomMask
                        anchors.fill: parent
                        radius: 4
                        visible: false
                    }
                    
                    Image {
                        id: bottomImg
                        anchors.fill: parent
                        source: pickerWindow.activeWallpaperPath ? ("file://" + pickerWindow.activeWallpaperPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        
                        // 💡 THE FIX: Integer bounds mapping
                        sourceSize.width: 64
                        sourceSize.height: 64
                        
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: bottomImg
                        maskSource: bottomMask
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    
                    Text {
                        text: pickerWindow.activeWallpaperPath ? pickerWindow.activeWallpaperPath.split('/').pop().split('.')[0] : "No wallpaper active"
                        color: Colors.workspaceactive
                        font.pixelSize: 14
                        font.bold: true
                    }
                    
                    Text {
                        text: pickerWindow.activeWallpaperPath ? (pickerWindow.activeWallpaperPath.split('Wallpapers/')[1] || pickerWindow.activeWallpaperPath) : ""
                        color: Colors.workspace
                        opacity: 0.5
                        font.pixelSize: 12
                        width: parent.parent.width - 150
                        elide: Text.ElideLeft
                    }
                }
            }
        }
    }
}