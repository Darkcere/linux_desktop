pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 💡 THE FIX 1: Swapped 'Item' for 'QtObject'. 
// Data Singletons should never participate in the visual Scene Graph!
QtObject {
    id: root

    // 💡 THE FIX 2: Fast native color math. 
    // We now pass a native color object instead of a hex string, bypassing the string parser!
    function alpha(c, opacity) {
        return Qt.rgba(c.r, c.g, c.b, opacity)
    }

    property color background: theme.background
    property color workspaceurgent: theme.workspaceurgent
    property color workspaceactive: theme.workspaceactive
    property color border: theme.border
    property color workspace: theme.workspace
    property color text: theme.text
    
    // 💡 THE FIX 3: Bind to 'root.text' (a native color) instead of 'theme.text' (a string)
    property color workspaceempty: alpha(root.text, 0.8)
    
    property color secondary: theme.secondary
    property color outline: theme.outline

    // 💡 THE FIX 4: Wrap the FileView in a property so it attaches safely to the QtObject
    property FileView watcher: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json" 
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: theme
            
            // Safe fallbacks on first boot
            property string background: "#12140e"
            property string workspaceurgent: "#ff8678"
            property string workspaceactive: "#86cf00"
            property string border: "#dafaa1"
            property string workspace: "#659c00"
            property string text: "#dafaa1"
            property string secondary: "#4c7a00"
            property string outline: "#a68b7e"
        }
    }
}