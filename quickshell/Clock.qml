import QtQuick
import QtQuick.Layouts
import QtQuick.Controls // Required for MonthGrid and DayOfWeekRow
import Quickshell

Text {
    id: root
    
    // --- STATE TRACKING ---
    property bool showSeconds: false
    property bool showCalendar: false 

    // Provides the time data
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Layout.alignment: Qt.AlignVCenter
    
    text: Qt.formatDateTime(clock.date, root.showSeconds ? "ddd, MMM dd, yyyy (hh:mm:ss)" : "hh:mm")
    color: Colors.text
    font.weight: 600
    font.pixelSize: 13
    
    HoverHandler { id: clockHover }

    // --- 1. MULTI-BUTTON MOUSE AREA ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        
        // FIX: Explicitly tell QML to listen to both clicks!
        acceptedButtons: Qt.LeftButton | Qt.RightButton 
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.showSeconds = !root.showSeconds;
            } else if (mouse.button === Qt.RightButton) {
                root.showCalendar = !root.showCalendar;
            }
        }
    }
    
    // --- 2. THE ANIMATED TOOLTIP ---
    BarToolTip {
        targetItem: root
        // Hide the tooltip if the calendar is currently open to prevent overlapping clutter
        active: clockHover.hovered && !root.showCalendar
        text: "Left Click to toggle seconds\nRight Click to open calendar"
        topMargin: 20
    }

    // --- 3. THE ANIMATED WAYLAND CALENDAR ---
    PopupWindow {
        id: calendarPopup
        
        property bool active: root.showCalendar

        // Explicit Wayland dimensions
        implicitWidth: calBg.width
        implicitHeight: calBg.height + 15
        color: "transparent"

        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins { top: 20 }
        }

        // -- Wayland Safe-Hide Logic (Same as your tooltips!) --
        Timer {
            id: calAnimTimer
            interval: 20
            onTriggered: calBg.show = true
        }

        onActiveChanged: {
            if (active) {
                calKillTimer.stop();
                calendarPopup.visible = true;
                calAnimTimer.start();
            } else {
                calAnimTimer.stop();
                calBg.show = false;
                calKillTimer.start();
            }
        }

        Timer {
            id: calKillTimer
            interval: 150
            onTriggered: calendarPopup.visible = false
        }

        // -- The Calendar UI --
        Item {
            anchors.fill: parent

            Rectangle {
                id: calBg
                property bool show: false
                
                width: 220
                height: calColumn.implicitHeight + 24
                anchors.horizontalCenter: parent.horizontalCenter
                
                color: Colors.background
                border.color: Colors.border
                border.width: 2
                radius: 5
                
                opacity: show ? 1.0 : 0.0
                y: show ? 0 : 10
                
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                Column {
                    id: calColumn
                    anchors.centerIn: parent
                    spacing: 12

                    // A. Header (Month & Year)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "MMMM yyyy")
                        color: Colors.text
                        font.pixelSize: 14
                        font.weight: 600
                    }

                    // B. Days of the Week Header (M T W T F S S)
                    DayOfWeekRow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 180
                        font.pixelSize: 11
                        font.weight: 600
                        delegate: Text {
                            text: model.shortName
                            color: Colors.text
                            opacity: 0.5 // Dim the headers slightly
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // C. The Number Grid
                    MonthGrid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 180
                        month: clock.date.getMonth()
                        year: clock.date.getFullYear()

                        delegate: Rectangle {
                            width: 24
                            height: 24
                            radius: 12 // Perfect circle
                            
                            // Highlight the current day using your border color
                            color: model.today ? Colors.workspaceactive : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: model.day
                                font.pixelSize: 11
                                font.weight: model.today ? 700 : 500
                                color: Colors.text
                                
                                // Dim days that spill over from the previous/next months
                                opacity: model.month === clock.date.getMonth() ? 1.0 : 0.3
                            }
                        }
                    }
                }
            }
        }
    }
}