import QtQuick
import Quickshell
import Quickshell.Io

Row {
    id: root
    height: 18 
    spacing: 3
    property var barRects: new Array(10)
    
    // Add a timestamp tracker
    property real lastUpdate: 0

    Process {
        id: cavaProc
        command: ["sh", "-c", "cava -p ~/.config/cava/quickshell.conf"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                // THROTTE: Only process if it has been at least 30ms
                let now = Date.now();
                if (now - root.lastUpdate < 30) return; 
                root.lastUpdate = now;

                let parts = data.trim().split(";");
                for (let i = 0; i < 10; i++) {
                    let val = parseInt(parts[i]) || 0;
                    let bar = root.barRects[i];
                    if (bar) {
                        // Using a small local variable for height is faster
                        let newHeight = Math.min(Math.max(val, 3), root.height);
                        if (bar.height !== newHeight) {
                            bar.height = newHeight;
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: 10 
        Item {
            width: 3
            height: root.height 
            Rectangle { 
                id: visualizerBar
                anchors.verticalCenter: parent.verticalCenter 
                width: parent.width
                height: 3 
                color: Colors.border
                radius: width / 2 
                Component.onCompleted: root.barRects[index] = visualizerBar
            }
        }
    }
}