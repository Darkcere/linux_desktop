// Theme.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    /* ───────── Bar ───────── */
    property color barBackground: "#0a0404"
    property color barBorder: "#f1908a"

    /* ───────── Accent / Brand ───────── */
    property color accent: "#f1908a"
    property color accentActive: "#d13a3a"

    /* ───────── Text ───────── */
    property color textPrimary: "#f1908a"
    property color textMuted: "#b07a75"

    /* ───────── Workspace dots ───────── */
    property color workspaceInactive: "#f1908a"
    property color workspaceActive: "#d13a3a"
    property real workspaceOpacityInactive: 0.4
    property real workspaceOpacityOccupied: 0.7
}

