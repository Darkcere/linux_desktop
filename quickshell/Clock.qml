import QtQuick
import Quickshell

Text {
    id: root
    
    // --- STATE TRACKING ---
    property bool showSeconds: false

    // Provides the time data
    SystemClock {
        id: clock
        
        // OPTIMIZATION: Only wake the CPU every second IF we are actually displaying seconds!
        // Otherwise, let the CPU sleep for a full minute.
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }    
    
    text: Qt.formatDateTime(clock.date, root.showSeconds ? "dddd, MMMM dd, yyyy (hh:mm:ss)" : "hh:mm")
    color: Colors.text
    font.weight: 600
    font.pixelSize: 13
    
    // 💡 THE FIX: HoverHandler handles both the tooltip state AND the custom cursor natively!
    HoverHandler { 
        id: clockHover 
        cursorShape: Qt.PointingHandCursor
    }

    // 💡 THE FIX: TapHandler replaces MouseArea. It handles the click in C++ 
    // without creating a physical, invisible box in the Scene Graph!
    TapHandler {
        acceptedButtons: Qt.LeftButton 
        onTapped: root.showSeconds = !root.showSeconds
    }
    
    // --- THE ANIMATED TOOLTIP ---
    BarToolTip {
        targetItem: root
        active: clockHover.hovered
        text: "Left Click to toggle seconds"
        topMargin: 23
    }
}