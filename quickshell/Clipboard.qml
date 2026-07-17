import Quickshell
import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: clipboardWindow
    
    property bool isOpen: false
    signal closeRequested()

    // 💡 Read from the instant C++ cache immediately on startup
    property var fullClipData: JSON.parse(clipboardSettings.cachedClips === "" ? "[]" : clipboardSettings.cachedClips)
    property var currentClipData: fullClipData 
    property int selectedIndex: 0
    
    // Track current preview metadata
    property string metaType: "Text"
    property string metaSize: "0 bytes"
    
    Settings {
        id: clipboardSettings
        category: "CaelestiaClipboard"
        property string cachedClips: "[]"
    }
    // --- TIMERS ---
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }

    Timer {
        id: previewDebounce
        interval: 150
        onTriggered: clipboardWindow.loadPreview()
    }

    onIsOpenChanged: {
        if (isOpen) {
            fetchClipsProcess.running = true
            focusTimer.start()
        }
    }

    onSelectedIndexChanged: {
        if (isOpen && currentClipData.length > 0) {
            previewDebounce.restart()
        }
    }

    // --- DATA FETCHING ---
    Process {
        id: fetchClipsProcess
        command: ["bash", "-c", "cliphist list | head -n 60"] 
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") {
                    clipboardWindow.fullClipData = [];
                    clipboardWindow.currentClipData = [];
                    clipboardWindow.metaType = "None";
                    clipboardWindow.metaSize = "0 bytes";
                    clipboardWindow.loadPreview();
                    return;
                }
                
                let lines = text.trim().split('\n');
                let tempArr = [];
                
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split('\t');
                    if (parts.length >= 2) {
                        let idStr = parts[0];
                        let rawText = parts.slice(1).join('\t');
                        
                        let isImg = rawText.includes("[[ binary data");
                        let displayTitle = isImg ? "Image Data" : rawText.trim().substring(0, 120).replace(/\n/g, " ");
                        
                        tempArr.push({ 
                            clipId: idStr, 
                            clipTitle: displayTitle,
                            isImage: isImg,
                            rawText: rawText
                        });
                    }
                }
                
                clipboardWindow.fullClipData = tempArr;
                clipboardWindow.currentClipData = tempArr;
                clipboardWindow.selectedIndex = 0;
                clipboardWindow.loadPreview();
            }
        }
    }
    
    function filterClips(query) {
        let lowerQuery = query.toLowerCase();
        
        // 💡 THE FIX: Native JS array filtering is lightning fast!
        if (lowerQuery === "") {
            clipboardWindow.currentClipData = clipboardWindow.fullClipData;
        } else {
            clipboardWindow.currentClipData = clipboardWindow.fullClipData.filter(
                item => item.clipTitle.toLowerCase().includes(lowerQuery)
            );
        }
        
        clipboardWindow.selectedIndex = 0;
        clipboardWindow.loadPreview();
    }

    // --- PREVIEW LOGIC ---
    Process {
        id: previewProcess
        property bool fetchingImage: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (!previewProcess.fetchingImage) {
                    previewText.text = text;
                    previewImage.visible = false;
                    previewTextScroll.visible = true;
                    clipboardWindow.metaSize = text.length + " chars";
                } else {
                    let cleanB64 = text.replace(/\n/g, "");
                    previewImage.source = "data:image/png;base64," + cleanB64;
                    previewTextScroll.visible = false;
                    previewImage.visible = true;
                }
            }
        }
    }

    function loadPreview() {
        if (clipboardWindow.currentClipData.length === 0 || selectedIndex < 0) {
            previewText.text = "No item selected.";
            previewImage.visible = false;
            previewTextScroll.visible = true;
            clipboardWindow.metaType = "None";
            clipboardWindow.metaSize = "0 bytes";
            return;
        }

        // 💡 Use the array index directly
        let item = clipboardWindow.currentClipData[selectedIndex];
        
        if (item.isImage) {
            clipboardWindow.metaType = "Image";
            let match = item.rawText.match(/\[\[ binary data (.*?) \]\]/);
            clipboardWindow.metaSize = match ? match[1] : "Unknown size";
            
            previewProcess.fetchingImage = true;
            previewProcess.command = ["bash", "-c", "cliphist decode " + item.clipId + " | base64 -w 0"];
        } else {
            clipboardWindow.metaType = "Text";
            previewProcess.fetchingImage = false;
            previewProcess.command = ["cliphist", "decode", item.clipId];
        }
        
        previewProcess.running = true;
    }

    function copyClip(idStr) {
        if (!idStr) return;
        let bashCmd = "cliphist decode " + idStr + " | wl-copy && sleep 0.15 && wtype -M ctrl -k v -m ctrl";
        Quickshell.execDetached({ command: ["bash", "-c", bashCmd] });
        clipboardWindow.closeRequested();
    }
    
    function clearClipboard() {
        Quickshell.execDetached({ command: ["bash", "-c", "cliphist wipe"] });
        clipboardWindow.fullClipData = [];
        clipboardWindow.currentClipData = [];
        
        // 💡 THE FIX: Wipe the cache
        clipboardSettings.cachedClips = "[]";
        
        clipboardWindow.selectedIndex = -1;
        loadPreview();
        searchInput.forceActiveFocus();
    }
    
    // --- INJECTED UI ---
    Row {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // --- LEFT PANE (LIST) ---
        Column {
            width: (parent.width * 0.45) - 7.5
            height: parent.height
            spacing: 10

            Rectangle {
                width: parent.width
                height: 40
                color: Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1) 
                radius: 6
                border.color: Colors.border
                border.width: 1
                
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.text
                    font.pixelSize: 14
                    focus: true
                    
                    Text {
                        text: "Search Clipboard..."
                        color: Colors.text
                        opacity: 0.4
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text
                    }
                    
                    onTextChanged: clipboardWindow.filterClips(text)
                    
                    Keys.onEscapePressed: (event) => { event.accepted = true; clipboardWindow.closeRequested(); }
                    Keys.onDownPressed: (event) => {
                        event.accepted = true;
                        if (clipboardWindow.currentClipData.length > 0) {
                            clipboardWindow.selectedIndex = Math.min(clipboardWindow.selectedIndex + 1, clipboardWindow.currentClipData.length - 1);
                            clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onUpPressed: (event) => {
                        event.accepted = true;
                        if (clipboardWindow.currentClipData.length > 0) {
                            clipboardWindow.selectedIndex = Math.max(clipboardWindow.selectedIndex - 1, 0);
                            clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onReturnPressed: (event) => {
                        event.accepted = true;
                        if (clipboardWindow.selectedIndex >= 0 && clipboardWindow.selectedIndex < clipboardWindow.currentClipData.length) {
                            clipboardWindow.copyClip(clipboardWindow.currentClipData[clipboardWindow.selectedIndex].clipId);
                        }
                    }
                }
            }
            
            ListView {
                id: clipList
                width: parent.width
                height: parent.height - 90
                clip: true
                
                // 💡 Bind to JS Array
                model: clipboardWindow.currentClipData 
                currentIndex: clipboardWindow.selectedIndex
                spacing: 4
                
                delegate: Item {
                    width: clipList.width
                    height: 54
                    
                    Rectangle {
                        anchors.fill: parent
                        
                        // 💡 THE FIX: Back to currentIndex === index since the search bar holds the focus!
                        color: (clipMouseArea.containsMouse || clipList.currentIndex === index) ? Colors.workspaceactive : "transparent"
                        radius: 6
                        opacity: (clipMouseArea.containsMouse || clipList.currentIndex === index) ? 1.0 : 0.7
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12
                            
                            // ICON
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 4
                                color: "transparent"
                                border.color: Colors.border
                                border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.isImage ? "" : "T"
                                    font.pixelSize: 16
                                    color: (clipList.currentIndex === index) ? Colors.background : Colors.text
                                }
                            }
                            
                            // TEXT
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 56
                                spacing: 2
                                
                                Text {
                                    width: parent.width
                                    text: modelData.clipTitle
                                    color: (clipList.currentIndex === index) ? Colors.background : Colors.text
                                    font.pixelSize: 13
                                    font.bold: (clipList.currentIndex === index)
                                    elide: Text.ElideRight 
                                }
                                
                                Text {
                                    text: modelData.isImage ? "Image copied" : "Text snippet"
                                    color: (clipList.currentIndex === index) ? Colors.background : Colors.text
                                    opacity: 0.6
                                    font.pixelSize: 11
                                }
                            }
                        }
                        
                        MouseArea {
                            id: clipMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                clipboardWindow.selectedIndex = index;
                                clipboardWindow.copyClip(modelData.clipId);
                            }
                        }
                    }
                }
            }
            // --- BOTTOM ACTIONS ---
            Row {
                width: parent.width
                height: 30
                spacing: 10

                Rectangle {
                    width: (parent.width - 10)
                    height: parent.height
                    color: clearMouseArea.containsMouse ? Qt.rgba(Colors.workspaceurgent.r, Colors.workspaceurgent.g, Colors.workspaceurgent.b, 0.15) : "transparent"
                    border.color: Colors.border
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Colors.text
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: clipboardWindow.clearClipboard()
                    }
                }
            }
        }

        // --- RIGHT PANE (PREVIEW) ---
        Rectangle {
            width: (parent.width * 0.55) - 7.5
            height: parent.height
            color: "transparent"
            border.color: Colors.border
            border.width: 1
            radius: 6
            clip: true

            Column {
                anchors.fill: parent
                
                Rectangle {
                    width: parent.width
                    height: parent.height - 40
                    color: "transparent"
                    clip: true
                    
                    Flickable {
                        id: previewTextScroll
                        anchors.fill: parent
                        anchors.margins: 15
                        contentWidth: width
                        contentHeight: previewText.paintedHeight
                        visible: true
                        clip: true
                        
                        Text {
                            id: previewText
                            width: parent.width
                            wrapMode: Text.WrapAnywhere
                            color: Colors.text
                            font.pixelSize: 13
                            textFormat: Text.PlainText
                        }
                    }
                    
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        anchors.margins: 10
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        
                        // 💡 THE FIX: Don't create a dynamic Qt.size object, just assign directly
                        sourceSize.width: 400
                        sourceSize.height: 400
                        
                        visible: false
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.2) 
                    
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Colors.border }
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 20
                        
                        Text {
                            text: "Type: " + clipboardWindow.metaType
                            color: Colors.text
                            opacity: 0.7
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Size: " + clipboardWindow.metaSize
                            color: Colors.text
                            opacity: 0.7
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter to Copy and Paste"
                        color: Colors.workspaceactive
                        font.bold: true
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}