import Quickshell
import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: clipboardWindow
    
    property bool isOpen: false
    signal closeRequested()

    ListModel { id: clipModel }
    
    property var fullClipData: []
    property int selectedIndex: 0
    
    // Track current preview metadata
    property string metaType: "Text"
    property string metaSize: "0 bytes"

    // --- TIMERS ---
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }

    // Debounce the preview loading so holding the arrow key doesn't freeze the UI
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
        if (isOpen && clipModel.count > 0) {
            previewDebounce.restart()
        }
    }

    // --- DATA FETCHING ---
    Process {
        id: fetchClipsProcess
        command: ["bash", "-c", "cliphist list | head -n 60"] 
        stdout: StdioCollector {
            onStreamFinished: {
                clipModel.clear();
                fullClipData = [];
                
                if (text.trim() === "") return;
                
                let lines = text.trim().split('\n');
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split('\t');
                    if (parts.length >= 2) {
                        let idStr = parts[0];
                        let rawText = parts.slice(1).join('\t');
                        
                        // cliphist denotes images with [[ binary data ... ]]
                        let isImg = rawText.includes("[[ binary data");
                        let displayTitle = isImg ? "Image Data" : rawText.trim().substring(0, 120).replace(/\n/g, " ");
                        
                        let item = { 
                            idStr: idStr, 
                            title: displayTitle, 
                            isImage: isImg, 
                            rawText: rawText 
                        };
                        
                        fullClipData.push(item);
                        clipModel.append({ 
                            "clipId": item.idStr, 
                            "clipTitle": item.title,
                            "isImage": item.isImage,
                            "rawText": item.rawText
                        });
                    }
                }
                clipboardWindow.selectedIndex = 0;
                clipboardWindow.loadPreview();
            }
        }
    }
    
    function filterClips(query) {
        clipModel.clear();
        let lowerQuery = query.toLowerCase();
        
        for (let i = 0; i < fullClipData.length; i++) {
            if (fullClipData[i].title.toLowerCase().includes(lowerQuery)) {
                clipModel.append({ 
                    "clipId": fullClipData[i].idStr, 
                    "clipTitle": fullClipData[i].title,
                    "isImage": fullClipData[i].isImage,
                    "rawText": fullClipData[i].rawText
                });
            }
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
                    // It's text
                    previewText.text = text;
                    previewImage.visible = false;
                    previewTextScroll.visible = true;
                    clipboardWindow.metaSize = text.length + " chars";
                } else {
                    // It's an image. Append timestamp to force QML to bypass cache
                    previewImage.source = "file:///tmp/qs_clip_preview.png?t=" + Date.now();
                    previewTextScroll.visible = false;
                    previewImage.visible = true;
                }
            }
        }
    }

    function loadPreview() {
        if (clipModel.count === 0 || selectedIndex < 0) {
            previewText.text = "No item selected.";
            previewImage.visible = false;
            previewTextScroll.visible = true;
            return;
        }

        let item = clipModel.get(selectedIndex);
        
        if (item.isImage) {
            clipboardWindow.metaType = "Image";
            // Extract the size string if possible from "[[ binary data 45 KB jpg ]]"
            let match = item.rawText.match(/\[\[ binary data (.*?) \]\]/);
            clipboardWindow.metaSize = match ? match[1] : "Unknown size";
            
            previewProcess.fetchingImage = true;
            // Decode straight to a temp file, then echo a space so StdioCollector fires
            previewProcess.command = ["bash", "-c", "cliphist decode " + item.clipId + " > /tmp/qs_clip_preview.png && echo ' '"];
        } else {
            clipboardWindow.metaType = "Text";
            previewProcess.fetchingImage = false;
            previewProcess.command = ["cliphist", "decode", item.clipId];
        }
        
        previewProcess.running = true;
    }

    function copyClip(idStr) {
        if (!idStr) return;
        let bashCmd = "cliphist decode " + idStr + " | wl-copy";
        Quickshell.execDetached({ command: ["bash", "-c", bashCmd] });
        clipboardWindow.closeRequested();
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
                        if (clipModel.count > 0) {
                            clipboardWindow.selectedIndex = Math.min(clipboardWindow.selectedIndex + 1, clipModel.count - 1);
                            clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onUpPressed: (event) => {
                        event.accepted = true;
                        if (clipModel.count > 0) {
                            clipboardWindow.selectedIndex = Math.max(clipboardWindow.selectedIndex - 1, 0);
                            clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain);
                        }
                    }
                    Keys.onReturnPressed: (event) => {
                        event.accepted = true;
                        if (clipboardWindow.selectedIndex >= 0 && clipboardWindow.selectedIndex < clipModel.count) {
                            clipboardWindow.copyClip(clipModel.get(clipboardWindow.selectedIndex).clipId);
                        }
                    }
                }
            }
            
            ListView {
                id: clipList
                width: parent.width
                height: parent.height - 50
                clip: true
                model: clipModel
                currentIndex: clipboardWindow.selectedIndex
                spacing: 4
                
                delegate: Item {
                    width: clipList.width
                    height: 54
                    
                    Rectangle {
                        anchors.fill: parent
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
                                    text: model.isImage ? "" : "T"
                                    font.pixelSize: 16
                                    color: (clipList.currentIndex === index) ? Colors.background : Colors.text
                                }
                            }
                            
                            // TEXT
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 56 // Adjust for icon and spacing
                                spacing: 2
                                
                                Text {
                                    width: parent.width
                                    text: model.clipTitle
                                    color: (clipList.currentIndex === index) ? Colors.background : Colors.text
                                    font.pixelSize: 13
                                    font.bold: clipList.currentIndex === index
                                    elide: Text.ElideRight 
                                }
                                
                                Text {
                                    text: model.isImage ? "Image copied" : "Text snippet"
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
                                // Double click to copy
                                clipboardWindow.copyClip(model.clipId);
                            }
                        }
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
                
                // Content Area
                Rectangle {
                    width: parent.width
                    height: parent.height - 40
                    color: "transparent"
                    clip: true
                    
                    // TEXT PREVIEW
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
                    
                    // IMAGE PREVIEW
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        anchors.margins: 10
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        visible: false
                    }
                }
                
                // Footer / Metadata Area
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
                        text: "Enter to Copy"
                        color: Colors.workspaceactive
                        font.bold: true
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}