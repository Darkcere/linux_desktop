pragma Singleton

import QtQuick
import QtCore
import Quickshell

QtObject {
    property Settings store: Settings {
        id: settingsStore
        category: "CaelestiaFeatures"

        property bool enableBar: true
        property bool enableOsd: true
        property bool enableWallpaper: true
        property bool enableMedia: true
        property bool enableVisualizer: true
        property bool enableNotifications: true
        property bool enableNotificationPopups: true
        property bool enableTray: true
        property bool enableDashboardStats: true
        property bool enableNetworkMonitor: true
        property bool enableBluetooth: true
        property bool enableInactiveBar: true
        property bool enableSystemStats: true
        property bool enableDashboardCalendar: true
        property bool enableQuickSettings: true
        property bool enableNightLight: true
        property bool enableLauncher: true
        property bool enableClipboard: true
        property bool enableTools: true
        property bool enablePowerMenu: true
        property bool enableWallpaperPicker: true
        property bool enableAudioMenu: true
        property bool enableLockScreen: true
        property bool legacyMigrated: false
    }

    property alias enableBar: settingsStore.enableBar
    property alias enableOsd: settingsStore.enableOsd
    property alias enableWallpaper: settingsStore.enableWallpaper
    property alias enableMedia: settingsStore.enableMedia
    property alias enableVisualizer: settingsStore.enableVisualizer
    property alias enableNotifications: settingsStore.enableNotifications
    property alias enableNotificationPopups: settingsStore.enableNotificationPopups
    property alias enableTray: settingsStore.enableTray
    property alias enableDashboardStats: settingsStore.enableDashboardStats
    property alias enableNetworkMonitor: settingsStore.enableNetworkMonitor
    property alias enableBluetooth: settingsStore.enableBluetooth
    property alias enableInactiveBar: settingsStore.enableInactiveBar
    property alias enableSystemStats: settingsStore.enableSystemStats
    property alias enableDashboardCalendar: settingsStore.enableDashboardCalendar
    property alias enableQuickSettings: settingsStore.enableQuickSettings
    property alias enableNightLight: settingsStore.enableNightLight
    property alias enableLauncher: settingsStore.enableLauncher
    property alias enableClipboard: settingsStore.enableClipboard
    property alias enableTools: settingsStore.enableTools
    property alias enablePowerMenu: settingsStore.enablePowerMenu
    property alias enableWallpaperPicker: settingsStore.enableWallpaperPicker
    property alias enableAudioMenu: settingsStore.enableAudioMenu
    property alias enableLockScreen: settingsStore.enableLockScreen

    Component.onCompleted: {
        if (settingsStore.legacyMigrated) return;

        try {
            const path = Quickshell.env("HOME") + "/.config/quickshell/shell_settings.json";
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "file://" + path, false);
            xhr.send();

            if (xhr.status === 200 || xhr.status === 0) {
                const legacy = JSON.parse(xhr.responseText);
                if (legacy.enableBar !== undefined) settingsStore.enableBar = legacy.enableBar;
                if (legacy.enableOsd !== undefined) settingsStore.enableOsd = legacy.enableOsd;
            }
        } catch (error) {
            console.log("No legacy feature settings found.");
        }

        settingsStore.legacyMigrated = true;
    }
}
