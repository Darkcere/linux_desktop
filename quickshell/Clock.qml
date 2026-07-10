import QtQuick
import Quickshell

Text {
    id: root
    
    // --- STATE TRACKING ---
    property bool showSeconds: false

    // Provides the time data
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }    
    text: Qt.formatDateTime(clock.date, root.showSeconds ? "dddd, MMMM dd, yyyy (hh:mm:ss)" : "hh:mm")
    color: Colors.text
    font.weight: 600
    font.pixelSize: 13
    
    HoverHandler { id: clockHover }

    // --- 1. MOUSE AREA ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        
        acceptedButtons: Qt.LeftButton 
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.showSeconds = !root.showSeconds;
            }
        }
    }
    
    // --- 2. THE ANIMATED TOOLTIP ---
    BarToolTip {
        targetItem: root
        active: clockHover.hovered
        text: "Left Click to toggle seconds"
        topMargin: 20
    }
}