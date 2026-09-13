pragma Singleton
import QtQuick
import QtCore
import Quickshell

Item {
    id: service

    // Expose settings globally
    property alias temperature: nlSettings.temperature
    property alias scheduleEnabled: nlSettings.scheduleEnabled
    property alias startTime: nlSettings.startTime
    property alias endTime: nlSettings.endTime

    Settings {
        id: nlSettings
        category: "NightLight"
        property int temperature: 4500
        property bool scheduleEnabled: false
        property string startTime: "20:00"
        property string endTime: "07:00"
    }

    // Centralized command execution
    function applyNightLight(onlyIfRunning) {
        let temp = Math.round(service.temperature);
        let cmd = onlyIfRunning 
            ? "if pgrep -x hyprsunset >/dev/null; then pkill -x hyprsunset || true; sleep 0.1; nohup hyprsunset -t " + temp + " >/dev/null 2>&1 & disown; fi"
            : "pkill -x hyprsunset || true; sleep 0.1; nohup hyprsunset -t " + temp + " >/dev/null 2>&1 & disown";
        
        Quickshell.execDetached({ command: ["bash", "-c", cmd] });
    }
    
    function stopNightLight() {
        Quickshell.execDetached({ command: ["bash", "-c", "pkill -x hyprsunset"] });
    }
    
    // Track the active state so we only trigger changes when crossing the threshold
    property bool _isNightActive: false

    function checkSchedule() {
        if (!service.scheduleEnabled) return;
        
        let d = new Date();
        let currentMins = d.getHours() * 60 + d.getMinutes();
        
        let startParts = service.startTime.split(":");
        let startMins = parseInt(startParts[0]) * 60 + parseInt(startParts[1]);
        
        let endParts = service.endTime.split(":");
        let endMins = parseInt(endParts[0]) * 60 + parseInt(endParts[1]);
        
        let shouldBeNight = false;
        
        // Handle normal times (e.g. 08:00 to 20:00) vs crossing midnight (e.g. 20:00 to 07:00)
        if (startMins <= endMins) {
            shouldBeNight = currentMins >= startMins && currentMins < endMins;
        } else {
            shouldBeNight = currentMins >= startMins || currentMins < endMins;
        }
        
        // Apply changes only if the state needs to flip
        if (shouldBeNight && !_isNightActive) {
            service.applyNightLight(false);
            _isNightActive = true;
        } else if (!shouldBeNight && _isNightActive) {
            service.stopNightLight();
            _isNightActive = false;
        }
    }

    Timer {
        interval: 60000 
        running: service.scheduleEnabled
        repeat: true
        onTriggered: checkSchedule()
    }

    // Run the check immediately when the singleton boots or the schedule is toggled
    Component.onCompleted: checkSchedule()
    
    onScheduleEnabledChanged: {
        if (scheduleEnabled) {
            checkSchedule();
        } else {
            stopNightLight();
            _isNightActive = false;
        }
    }
}