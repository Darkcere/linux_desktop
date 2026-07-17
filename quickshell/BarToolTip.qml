import QtQuick
import Quickshell
import Quickshell.Wayland // 💡 THE FIX: Required for the click-through Region mask!

PopupWindow {
    id: root

    property string text: ""
    property bool active: false
    property int delay: 300
    
    property int topMargin: 6 
    property string align: "center" 
    property int xOffset: 0         
    property int bridgeReach: 3     
    property int windowPadding: 6
    
    property Item targetItem: null

    // 💡 THE FIX: Hard width/height commands for the physical window
    width: tooltipBackground.width + Math.abs(root.xOffset) + (root.windowPadding * 2)
    height: tooltipBackground.fullHeight + root.bridgeReach + root.windowPadding 
    color: "transparent"

    // 💡 THE FIX: The Wayland click-through mask. 
    // This absolutely guarantees the tooltip can NEVER steal the mouse hover 
    // state away from your panel buttons!
    mask: Region {}

    anchor {
        item: root.targetItem
        edges: Edges.Bottom
        
        // 💡 THE FIX: Fast ternary evaluation instead of an if-return block
        gravity: root.align === "left" ? (Edges.Bottom | Edges.Left) : 
                 (root.align === "right" ? (Edges.Bottom | Edges.Right) : Edges.Bottom)
                 
        margins { 
            top: root.topMargin - root.bridgeReach 
            left: root.align === "left" ? -root.windowPadding : 0
            right: root.align === "right" ? -root.windowPadding : 0
        }
    }

    // --- 1. The Spawn Sequence ---
    Timer {
        id: spawnTimer
        interval: root.delay
        running: root.active
        onTriggered: {
            root.visible = true; 
            animTimer.start(); 
        }
    }

    Timer {
        id: animTimer
        interval: 20 
        onTriggered: tooltipBackground.show = true
    }

    // --- 2. The Kill Sequence ---
    onActiveChanged: {
        if (active) {
            killTimer.stop(); 
        } else {
            spawnTimer.stop();
            animTimer.stop();
            tooltipBackground.show = false; 
            killTimer.start(); 
        }
    }

    Timer {
        id: killTimer
        interval: 200 
        onTriggered: root.visible = false 
    }

    // --- 3. The Visuals ---
    Item {
        anchors.fill: parent
        anchors.margins: root.windowPadding
        anchors.topMargin: 0 

        Item {
            id: shiftWrapper
            width: tooltipBackground.width
            height: parent.height

            anchors.top: parent.top
            anchors.left: root.align === "left" ? parent.left : undefined
            anchors.right: root.align === "right" ? parent.right : undefined
            anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
            
            anchors.leftMargin: root.align === "left" ? root.xOffset : 0
            anchors.rightMargin: root.align === "right" ? -root.xOffset : 0
            anchors.horizontalCenterOffset: root.align === "center" ? root.xOffset : 0

            Rectangle {
                id: tooltipBackground
                property bool show: false
                
                // 💡 THE FIX: Removed the redundant contentWrapper Item. 
                // The background reads the label's implicit size directly!
                property int fullHeight: label.implicitHeight + 16
                width: label.implicitWidth + 24
                height: show ? fullHeight : 0
                
                anchors.top: parent.top
                anchors.topMargin: root.bridgeReach
                anchors.left: parent.left
                
                color: Colors.background
                border.color: Colors.border
                border.width: 2
                radius: 8
                clip: true 

                opacity: show ? 1.0 : 0.0

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                    color: Colors.text
                    font.pixelSize: 11
                    font.weight: 600
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    lineHeight: 1.2 
                }
            }

            // THE BRIDGE
            Rectangle {
                id: seamlessBridge
                opacity: tooltipBackground.opacity
                visible: opacity > 0
                
                anchors.top: parent.top 
                anchors.left: tooltipBackground.left
                anchors.right: tooltipBackground.right
                height: root.bridgeReach + 8 
                color: Colors.background
                
                Rectangle { anchors.left: parent.left; width: 2; height: parent.height; color: Colors.border }
                Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Colors.border }
            }
        }
    }
}