import QtQuick
import Quickshell
import Quickshell.Io

Row {
    id: root
    height: 18 
    spacing: 3
    property var barRects: new Array(10)

    Process {
        id: cavaProc
        command: ["sh", "-c", "exec cava -p ~/.config/cava/quickshell.conf"]
        
        // Always running, as requested!
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                // We rely on cava.conf's 'framerate=30' to throttle the output natively,
                // so we don't need Date.now() JS checks here anymore.

                let parts = data.trim().split(";");
                for (let i = 0; i < 10; i++) {
                    // Fast integer conversion
                    let val = parseInt(parts[i]) || 0;
                    let bar = root.barRects[i];
                    
                    if (bar) {
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