pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    readonly property real hardMaxValue: 2.00

    // --- 1. THE OPTIMIZATION: NATIVE STATE TRACKING ---
    // These properties run purely in C++ and won't break if a headset is hot-plugged
    readonly property real sinkVol: sink?.audio?.volume ?? 0
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    
    readonly property real micVol: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // --- 2. AUTOMATIC SIGNAL EMITTERS ---
    // This entirely replaces the heavy 'Connections' blocks
    onSinkVolChanged: if (sink?.ready) volumeChanged(sinkVol, sinkMuted, sink)
    onSinkMutedChanged: if (sink?.ready) volumeChanged(sinkVol, sinkMuted, sink)

    onMicVolChanged: if (source?.ready) micVolumeChanged(micVol, micMuted, source)
    onMicMutedChanged: if (source?.ready) micVolumeChanged(micVol, micMuted, source)

    // --- 3. PROTECTION SETTINGS ---
    property bool protectionEnabled: true
    readonly property real maxVolumeJump: 0.15 
    property bool protectionTriggered: false

    signal sinkProtectionTriggered(string reason)
    signal volumeChanged(real volume, bool muted, var node)
    signal micVolumeChanged(real volume, bool muted, var node)

    PwObjectTracker {
        objects: [sink, source]
    }

    // Note: I kept the 'node' parameter so we don't break the function call in your AudioModule.qml, 
    // even though the function doesn't actually need to use it!
    function protectedSetVolume(node, targetVolume: real, currentVolume: real) {
        if (!root.protectionEnabled) return targetVolume;
        const jump = targetVolume - currentVolume;
        
        if (jump <= 0) {
            root.protectionTriggered = false;
            return targetVolume;
        }
        if (jump > root.maxVolumeJump) {
            root.protectionTriggered = true;
            root.sinkProtectionTriggered("Volume jump limited");
            protectionResetTimer.restart();
            return currentVolume + root.maxVolumeJump;
        }
        
        root.protectionTriggered = false;
        return targetVolume;
    }

    Timer {
        id: protectionResetTimer
        interval: 1500
        onTriggered: root.protectionTriggered = false
    }

    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }
}