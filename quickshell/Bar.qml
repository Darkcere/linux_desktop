import Quickshell
import QtQuick
import Quickshell.Wayland

PanelWindow {
    id: mainBarWindow 
    property var modelData
    WlrLayershell.layer: WlrLayer.Top
    property bool isGameMode: false
    property var menuHandler
    property QtObject globalTrayMenu
    property bool isDropdownOpen: false
    property int dropdownWidth: 0
    
    property bool hasNotifications: NotificationManager.list.length > 0 
    property bool hasActivePopup: NotificationManager.popupList.length > 0

    property bool dndEnabled: false

    signal toggleLauncherRequested()
    signal toggleDashboardRequested()
    signal togglePowerRequested()
    // --- HELPER PROPERTIES FOR CLEANER LOGIC ---
    property bool isRightAlignedMode: menuHandler && (menuHandler.lastActiveView === "tray" || menuHandler.lastActiveView === "audio" || menuHandler.lastActiveView === "notifications")
    property bool isRightMenuOpen: menuHandler && (menuHandler.activeView === "tray" || menuHandler.activeView === "audio" || menuHandler.activeView === "notifications")

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 2
        left: 8
        right: 8
    }

    // 💡 THE FIX: Hard command instead of a suggestion
    height: 28
    color: "transparent"

    Rectangle {
        id: barVisuals
        // 💡 THE FIX: Bind directly to the parent's hard command
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        
        anchors.horizontalCenter: mainBarWindow.isRightAlignedMode ? undefined : parent.horizontalCenter
        anchors.right: mainBarWindow.isRightAlignedMode ? parent.right : undefined
        
        width: mainBarWindow.isDropdownOpen ? mainBarWindow.dropdownWidth : mainBarWindow.width
        radius: mainBarWindow.isGameMode ? 0 : mainBarWindow.isDropdownOpen ? 12 : 5
        
        color: Colors.background
        border.color: Colors.border
        border.width: mainBarWindow.isGameMode ? 1 : 2
        clip: true 

        Behavior on width { 
            enabled: !mainBarWindow.isGameMode // 👈 Disables animation in Game Mode
            NumberAnimation { duration: menuHandler ? menuHandler.morphSpeed : 300; easing.type: Easing.OutQuart } 
        }
        Behavior on radius { 
            enabled: !mainBarWindow.isGameMode
            NumberAnimation { duration: menuHandler ? menuHandler.morphSpeed : 300; easing.type: Easing.OutQuart } 
        }

        // --- 1. DROPDOWN BRIDGE ---
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12 
            color: Colors.background
            
            opacity: mainBarWindow.isDropdownOpen ? 1 : 0 
            visible: opacity > 0
            
            Rectangle { anchors.left: parent.left; width: mainBarWindow.isGameMode ? 1 : 2; height: parent.height; color: Colors.border }
            Rectangle { anchors.right: parent.right; width: mainBarWindow.isGameMode ? 1 : 2; height: parent.height; color: Colors.border }
            
            Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: menuHandler ? (menuHandler.morphSpeed / 2) : 100 } }
        }

        // --- 2. NOTIFICATION POPUP BRIDGE ---
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            
            width: 348
            height: 12 
            color: Colors.background

            opacity: (!mainBarWindow.isDropdownOpen && mainBarWindow.hasActivePopup) ? 1 : 0
            visible: opacity > 0
            
            // THE FIX: Set height back to 2 so it doesn't slice up into the bar!
            Rectangle { 
                anchors.left: parent.left; 
                anchors.bottom: parent.bottom; 
                width: 2; 
                height: 2; 
                color: Colors.border 
            }
            Rectangle { 
                anchors.right: parent.right; 
                anchors.bottom: parent.bottom; 
                width: 2; 
                height: parent.height; 
                color: Colors.border 
            }
            
            Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: 150 } }
        }

        Item {
            id: innerContent
            x: -barVisuals.x 
            y: 0
            width: mainBarWindow.width
            // 💡 THE FIX: Hard command
            height: mainBarWindow.height

            Item {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                
                // --- LEFT ROW ---
                Loader {
                    id:leftRowbar
                    anchors.fill: parent
                    active: !menuHandler?.activeView 
                    sourceComponent: Component {
                        Row {
                            spacing: 8 
                            
                            Behavior on opacity { 
                                enabled: !mainBarWindow.isGameMode
                                NumberAnimation { duration: 150 } 
                            }
                            
                            Text {
                                id: archlogo
                                text: "󰣇"
                                color: Colors.text
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { 
                                    enabled: !mainBarWindow.isGameMode
                                    ColorAnimation { duration: 150 } 
                                }
                                
                                // 💡 THE FIX: Zero-geometry input handling
                                HoverHandler {
                                    id: archHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onTapped: mainBarWindow.toggleDashboardRequested()
                                }

                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: mainBarWindow.toggleLauncherRequested()
                                }
                                TapHandler {
                                    acceptedButtons: Qt.MiddleButton
                                    onTapped: mainBarWindow.togglePowerRequested()
                                }
                                BarToolTip {
                                    targetItem: archlogo
                                    active: !isGameMode && archHover.hovered
                                    text: "<b>Left Click:</b> Open Dashboard<br><b>Right Click:</b> Open Launcher<br><b>Middle Click:<b> Open Power Menu"
                                    topMargin: 24
                                }
                            }
                            
                            Workspaces {isGameMode: mainBarWindow.isGameMode; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                
                
                // --- CENTER ROW ---
                Loader {
                    anchors.centerIn: parent
                    active: !mainBarWindow.isRightMenuOpen 
                    
                    sourceComponent: Component {
                        Row {
                            spacing: 5 
                            Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: 150 } }
                            
                            Clock { 
                                id: barclock
                                z: -1 
                                anchors.verticalCenter: parent.verticalCenter 
                                anchors.verticalCenterOffset: -1
                                isDropdownOpen: mainBarWindow.isDropdownOpen 

                                // 1. You must declare the HoverHandler so it can detect the mouse
                                HoverHandler {
                                    id: clockHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                // 2. Now the tooltip can read clockHover.hovered
                                BarToolTip {
                                    targetItem: barclock
                                    // Hide tooltip in Game Mode to save resources
                                    active: clockHover.hovered && !mainBarWindow.isGameMode
                                    text: "Left Click to toggle seconds and date"
                                    topMargin: 24
                                }
                            }
                            Mediaplayer { z: 10; anchors.verticalCenter: parent.verticalCenter; isDashboardopen: isDropdownOpen && menuHandler.lastActiveView === "dashboard"; visible: SettingsService.enableMedia && !mainBarWindow.isGameMode }
                        }
                    }
                }
                // --- RIGHT ROW ---
                Loader {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    active: mainBarWindow.isRightMenuOpen || !menuHandler?.activeView 
                    sourceComponent: Component {
                        Row {
                            spacing: 5 
                            
                            // --- 1. AUDIO ---
                            AudioModule {
                                property bool isActive: !(menuHandler && menuHandler.activeView && menuHandler.activeView !== "audio")
                                anchors.verticalCenter: parent.verticalCenter
                                width: isActive ? implicitWidth : 0
                                opacity: isActive ? 1 : 0
                                clip: true 
                                visible: width > 0 
                                audiotooltip: !isGameMode && !hasActivePopup 
                                
                                Behavior on width {NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: 150 } }
                            }
                            
                            // --- 2. NOTIFICATIONS ---
                            Text {
                                id: notificationbell
                                property bool isActive: SettingsService.enableNotifications && !(menuHandler && menuHandler.activeView && menuHandler.activeView !== "notifications")
                                
                                text: NotificationManager.silent 
                                ? (hasNotifications ? "" : "") 
                                : (hasNotifications ? "" : "")
                                color: Colors.text 
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                                
                                width: isActive ? implicitWidth : 0
                                opacity: isActive ? 1 : 0
                                clip: true 
                                visible: SettingsService.enableNotifications && width > 0
                                
                                Behavior on width {NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: 150 } }
                                
                                // 💡 THE FIX: Zero-geometry right/left click separation
                                HoverHandler {
                                    id: bellHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onTapped: (eventPoint, button) => {
                                        if (button === Qt.RightButton) {
                                            NotificationManager.silent = !NotificationManager.silent;
                                        } else {
                                            mainBarWindow.menuHandler.toggleNotifications();
                                        }
                                    }
                                }

                                BarToolTip {
                                    targetItem: notificationbell
                                    active: !isGameMode && bellHover.hovered && !hasActivePopup
                                    text: "Left Click: Open Notification Center\nRight Click: Toggle DND"
                                    topMargin: 24 
                                }
                            }
                            
                            // --- 3. TRAY ---
                            Tray { 
                                id: trayModule // Give it an ID so we can reference it easily
                                
                                property bool isActive: !(menuHandler && menuHandler.activeView && menuHandler.activeView !== "tray")
                                
                                anchors.verticalCenter: parent.verticalCenter
                                width: isActive ? implicitWidth : 0
                                opacity: isActive ? 1 : 0
                                clip: true 
                                traytooltip: !isGameMode && !hasActivePopup 
                                // 💡 THE FIX: Use the exposed integer property!
                                visible: SettingsService.enableTray && trayModule.itemCount > 0 
                                
                                Behavior on width {NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                                Behavior on opacity {enabled: !mainBarWindow.isGameMode; NumberAnimation { duration: 150 } }
                                
                                menuHandler: mainBarWindow.menuHandler
                            }
                            
                        }
                    }
                }
            }
        }
    }

}