import QtQuick
import Quickshell
import Quickshell.Io

// 💡 THE FIX 1: Dropped 'Row' for a primitive 'Item' with a mathematically pre-calculated width.
// 10 bars * 3px + 9 gaps * 3px = 57px total.
Item {
    id: root
    width: 57 
    height: 18 
    
    property var barRects: new Array(10)

    Process {
        id: cavaProc
        command: ["sh", "-c", "exec cava -p ~/.config/cava/quickshell.conf"]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                // 💡 THE FIX 2: Removed .trim() - the bitwise operator handles trailing spaces automatically!
                let parts = data.split(";");
                
                // 💡 THE FIX 3: Cache the array reference locally so we don't query the QML root object 10 times
                let bars = root.barRects;
                
                for (let i = 0; i < 10; i++) {
                    // 💡 THE FIX 4: Bitwise integer cast (Fastest JS cast)
                    let val = parts[i] | 0;
                    
                    // 💡 THE FIX 5: Ternary clamping (Bypasses Math function calls)
                    let newHeight = val < 3 ? 3 : (val > 18 ? 18 : val);
                    
                    if (bars[i] && bars[i].height !== newHeight) {
                        bars[i].height = newHeight;
                    }
                }
            }
        }
    }

    Repeater {
        model: 10 
        
        // 💡 THE FIX 6: Deleted the wrapping Item. The Rectangle handles its own math!
        Rectangle { 
            id: visualizerBar
            
            x: index * 6
            anchors.verticalCenter: parent.verticalCenter 
            
            width: 3
            height: 3 
            color: Colors.border
            
            // 💡 THE FIX 7: Pre-calculated static float instead of "width / 2"
            radius: 1.5 
            
            Component.onCompleted: root.barRects[index] = visualizerBar
        }
    }
}