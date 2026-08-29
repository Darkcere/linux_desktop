import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Rectangle {
    id: root
    
    // 💡 THE FIX: Tell the layout engine exactly how much space this needs to exist!
    implicitWidth: 260
    implicitHeight: 250
    
    color: "transparent"
    border.color: Colors.border
    border.width: 2
    radius: 20

    // State for changing months
    property int monthOffset: 0
    
    SystemClock { id: sysClock; precision: SystemClock.Hours }
    
    property var displayDate: {
        let d = new Date(sysClock.date);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: ""
                color: Colors.text
                opacity: prevHover.hovered ? 1.0 : 0.6
                font.pixelSize: 14
                
                HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.monthOffset -= 1 }
            }

            Text { 
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.displayDate, "MMMM yyyy")
                color: Colors.text
                font.pixelSize: 16
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                
                HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.monthOffset = 0 } // Click title to reset to current month
                
                ToolTip.visible: resetHover.hovered
                ToolTip.text: "Return to Today"
                ToolTip.delay: 500
            }
            
            Text { 
                text: ""
                color: Colors.text
                opacity: nextHover.hovered ? 1.0 : 0.6
                font.pixelSize: 14
                
                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.monthOffset += 1 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border }

        // --- Weekdays ---
        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale()
            delegate: Text {
                text: model.shortName
                color: Colors.text
                opacity: 0.6
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        // --- Grid ---
        MonthGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: root.displayDate.getMonth()
            year: root.displayDate.getFullYear()
            locale: Qt.locale()
            delegate: Rectangle {
                width: 24; height: 24; radius: 12
                color: model.today ? Colors.workspaceactive : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: model.day
                    color: model.today ? Colors.background : (model.month === root.displayDate.getMonth() ? Colors.text : Colors.border)
                    font.pixelSize: 13
                    font.weight: model.today ? Font.Bold : Font.Normal
                }
            }
        }
    }
}