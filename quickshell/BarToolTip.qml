import QtQuick
import Quickshell

PopupWindow {
    id: root

    property string text: ""
    property bool active: false
    property int delay: 300
    
    property int topMargin: 6 
    property string align: "center" 
    property int xOffset: 0         
    property int bridgeReach: 3     
    
    // 💡 NEW: The invisible Wayland safety buffer to prevent clipping!
    property int windowPadding: 6
    
    property Item targetItem: null

    // 💡 The Wayland surface is now safely larger than the visual box
    implicitWidth: tooltipBackground.width + Math.abs(root.xOffset) + (root.windowPadding * 2)
    implicitHeight: tooltipBackground.fullHeight + root.bridgeReach + root.windowPadding 
    color: "transparent"

    anchor {
        item: root.targetItem
        edges: Edges.Bottom
        gravity: {
            if (root.align === "left") return Edges.Bottom | Edges.Left;
            if (root.align === "right") return Edges.Bottom | Edges.Right;
            return Edges.Bottom; 
        }
        margins { 
            // 💡 Perfectly offsets the invisible padding so the visual alignment stays exact!
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
        // 💡 Pushes the visual box safely inside the padded bounds
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
                
                width: contentWrapper.width
                property int fullHeight: contentWrapper.height
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

                Item {
                    id: contentWrapper
                    width: label.implicitWidth + 24
                    height: label.implicitHeight + 16
                    anchors.top: parent.top
                    anchors.left: parent.left

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
                
                // 💡 Restored both border lines so there are no holes in your corners!
                Rectangle { anchors.left: parent.left; width: 2; height: parent.height; color: Colors.border }
                Rectangle { anchors.right: parent.right; width: 2; height: parent.height; color: Colors.border }
            }
        }
    }
}