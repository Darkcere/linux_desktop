import QtQuick
import Quickshell

PopupWindow {
    id: root

    property string text: ""
    property bool active: false
    property int delay: 300
    property int topMargin: 5 
    
    property int leftMargin: 0

    
    property Item targetItem: null

    // Explicit dimensions are safer for Wayland compositor buffers
    implicitWidth: tooltipBackground.width
    implicitHeight: tooltipBackground.height + 15 
    color: "transparent"

    anchor {
        item: root.targetItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins { 
            top: root.topMargin 
            left: root.leftMargin 
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
            // FIX: If the user hovers back rapidly, cancel the death sequence!
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
        interval: 150 
        onTriggered: root.visible = false 
    }

    // --- 3. The Animated Bubble ---
    Item {
        anchors.fill: parent

        Rectangle {
            id: tooltipBackground
            
            property bool show: false
            
            width: label.implicitWidth + 24
            height: label.implicitHeight + 14
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: Colors.background
            border.color: Colors.border
            border.width: 2
            radius: 5

            opacity: show ? 1.0 : 0.0
            y: show ? 0 : 10

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            Text {
                id: label
                anchors.centerIn: parent
                text: root.text
                color: Colors.text
                font.pixelSize: 11
                font.weight: 600
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}