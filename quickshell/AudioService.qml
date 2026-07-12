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

    // --- OPTIMIZATION 1: Deleted manual state trackers and signals ---
    // Your AudioModule UI already binds directly to `sink.audio.volume`.
    // QML handles those updates natively in C++, making these JS signals redundant.

    // --- PROTECTION SETTINGS ---
    property bool protectionEnabled: true
    readonly property real maxVolumeJump: 0.15 
    property bool protectionTriggered: false

    signal sinkProtectionTriggered(string reason)

    PwObjectTracker {
        objects: [sink, source]
    }

    // OPTIMIZATION 2: Replaced 'var' with 'PwNode' for the node parameter
    // Because you used `pragma ComponentBehavior: Bound`, strong typing makes the function execute faster
    function protectedSetVolume(node: PwNode, targetVolume: real, currentVolume: real) {
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