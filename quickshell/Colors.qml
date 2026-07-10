pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    // 1. Your alpha function (updated slightly to ensure it parses the dynamic color correctly)
    function alpha(c, opacity) {
        let parsed = Qt.color(c)
        return Qt.rgba(parsed.r, parsed.g, parsed.b, opacity)
    }

    // 2. Your properties. Notice they are no longer "readonly", 
    // and they bind directly to the JSON adapter below.
    property color background: theme.background
    property color workspaceurgent: theme.workspaceurgent
    property color workspaceactive: theme.workspaceactive
    property color border: theme.border
    property color workspace: theme.workspace
    property color text: theme.text
    
    // workspaceempty uses your alpha function just like before!
    property color workspaceempty: alpha(theme.text, 0.8)
    property color secondary: theme.secondary
    property color outline: theme.outline
    // 3. The magic watcher that updates the colors instantly
    FileView {
        id: watcher
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json" 
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: theme
            
            // These act as your safe fallbacks on first boot
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