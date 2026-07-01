import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup() 
        }
    }
    Bar {
        id: mainBarWindow
        globalTrayMenu: globalTrayMenu
    }

    TrayMenu {
        id: globalTrayMenu
        parentBarWindow: mainBarWindow
    }

    Osd {
        id: volumeOSD
    }
}