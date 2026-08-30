import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Networking
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    property bool isOpen: false
    signal closeRequested()
    
    // Live metrics properties
    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0
    property real gpuUsage: 0
    property var prevCpu: [0, 0]

    // 💡 Optimized Single Poll Timer (Queries CPU, RAM, Disk, and GPU all at once)
    Timer {
        interval: 2500
        running: root.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            systemStatsProc.running = true;
        }
    }

    Process {
        id: systemStatsProc
        command: ["python3", "-c", "
import glob

# 1. CPU usage via /proc/stat
try:
    with open('/proc/stat', 'r') as f:
        fields = [int(x) for x in f.readline().split()[1:]]
        idle = fields[3] + fields[4]
        total = sum(fields)
        print(f'CPU {idle} {total}')
except Exception:
    pass

# 2. RAM usage via /proc/meminfo
try:
    mem = {}
    with open('/proc/meminfo', 'r') as f:
        for line in f:
            parts = line.split(':')
            if len(parts) == 2:
                mem[parts[0].strip()] = int(parts[1].split()[0])
    total_mem = mem.get('MemTotal', 1)
    avail_mem = mem.get('MemAvailable', 0)
    ram_pct = round(((total_mem - avail_mem) / total_mem) * 100)
    print(f'RAM {ram_pct}')
except Exception:
    pass

# 3. Disk usage of root partition
try:
    st = __import__('os').statvfs('/')
    disk_pct = round(((st.f_blocks - st.f_bavail) / st.f_blocks) * 100)
    print(f'DISK {disk_pct}')
except Exception:
    pass

# 4. GPU usage for AMD RX 6600
try:
    for path in glob.glob('/sys/class/drm/card*/device/gpu_busy_percent'):
        with open(path, 'r') as f:
            print(f'GPU {f.read().strip()}')
            break
except Exception:
    pass
"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n');
                for (let line of lines) {
                    let parts = line.split(' ');
                    if (parts.length >= 2) {
                        let type = parts[0];
                        if (type === "CPU" && parts.length === 3) {
                            let idle = parseInt(parts[1]) || 0;
                            let total = parseInt(parts[2]) || 0;
                            let diffIdle = idle - root.prevCpu[0];
                            let diffTotal = total - root.prevCpu[1];
                            if (diffTotal > 0) {
                                let usage = 100 - Math.round((diffIdle / diffTotal) * 100);
                                root.cpuUsage = Math.min(100, Math.max(0, usage));
                            }
                            root.prevCpu = [idle, total];
                        } else if (type === "RAM") {
                            root.ramUsage = parseInt(parts[1]) || 0;
                        } else if (type === "DISK") {
                            root.diskUsage = parseInt(parts[1]) || 0;
                        } else if (type === "GPU") {
                            root.gpuUsage = Math.min(100, Math.max(0, parseInt(parts[1]) || 0));
                        }
                    }
                }
            }
        }
    }
    
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // --- COLUMN 2: MEDIA PLAYER ---
        Rectangle {
            id: mediaCard
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: "transparent"
            border.color: mediaCard.player ? Colors.workspaceactive : Colors.border
            border.width: 2
            radius: 20
            clip: true

            property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
            property real progress: 0
            property real vinylRotation: 0

            function formatTime(seconds) {
                if (seconds === undefined || seconds === null || isNaN(seconds)) return "0:00";
                let totalSec = Math.floor(Number(seconds));
                if (totalSec <= 0) return "0:00";
                
                let m = Math.floor(totalSec / 60);
                let s = totalSec % 60;
                return m + ":" + (s < 10 ? "0" : "") + s;
            }

            Timer {
                id: mediaTimer
                interval: 250 // Throttled to 250ms for low CPU usage while maintaining smooth animation
                running: root.isOpen && mediaCard.player !== null
                repeat: true
                triggeredOnStart: true
                
                onTriggered: {
                    if (mediaCard.player && mediaCard.player.length > 0) {
                        let newProg = mediaCard.player.position / mediaCard.player.length;
                        if (newProg !== mediaCard.progress) {
                            mediaCard.progress = newProg;
                            mediaCard.vinylRotation = newProg * 360;
                            progressCanvas.requestPaint();
                        }
                    } else {
                        mediaCard.progress = 0;
                        mediaCard.vinylRotation = 0;
                        progressCanvas.requestPaint();
                    }
                    timeLabel.text = mediaCard.formatTime(mediaCard.player?.position) + " / " + mediaCard.formatTime(mediaCard.player?.length);
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 140
                    
                    Canvas {
                        id: progressCanvas
                        anchors.fill: parent
                        property color trackColor: Colors.border
                        property color progressColor: Colors.workspaceactive
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            
                            ctx.beginPath();
                            ctx.arc(width/2, height/2, width/2 - 4, Math.PI * 0.75, Math.PI * 0.25);
                            ctx.strokeStyle = trackColor;
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.stroke();
                            
                            ctx.beginPath();
                            ctx.arc(width/2, height/2, width/2 - 4, Math.PI * 0.75, Math.PI * 0.75 + (mediaCard.progress * Math.PI * 1.5));
                            ctx.strokeStyle = progressColor;
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    Item {
                        id: artContainer
                        anchors.centerIn: parent
                        width: 110; height: 110
                        
                        rotation: mediaCard.vinylRotation

                        Behavior on rotation {
                            NumberAnimation { duration: 250; easing.type: Easing.Linear }
                        }

                        Rectangle { id: artMask; anchors.fill: parent; radius: width/2; visible: false }
                        
                        Image {
                            anchors.fill: parent
                            source: mediaCard.player ? mediaCard.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask { maskSource: artMask }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: Colors.workspaceactive
                                visible: parent.status === Image.Error || parent.source == ""
                                Text { anchors.centerIn: parent; text: "󰝚"; color: Colors.background; font.pixelSize: 40 }
                            }
                            
                            Rectangle {
                                anchors.centerIn: parent
                                visible: mediaCard.player ? true : false
                                width: 14; height: 14; radius: 7
                                color: Colors.background
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: mediaCard.player ? mediaCard.player.trackTitle : "No Media"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: mediaCard.player ? mediaCard.player.trackArtist : " "
                    color: Colors.text
                    opacity: 0.7
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15
                    
                    Text { 
                        text: "󰒟" 
                        color: (mediaCard.player && mediaCard.player.shuffle) ? Colors.workspaceactive : Colors.text
                        opacity: (mediaCard.player && mediaCard.player.shuffle) ? 1.0 : 0.5
                        font.pixelSize: 18 
                        MouseArea { 
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                            onClicked: {
                                if (!mediaCard.player) return;
                                let nextShuffle = mediaCard.player.shuffle ? "Off" : "On";
                                Quickshell.execDetached({ command: ["playerctl", "shuffle", nextShuffle] });
                                mediaCard.player.shuffle = !mediaCard.player.shuffle;
                            }
                        }
                    } 
                    
                    Text { 
                        text: "󰒮"; color: Colors.text; font.pixelSize: 22
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.previous() }
                    }
                    Rectangle {
                        width: 46; height: 36; radius: 12
                        color: Colors.workspaceactive
                        Text { 
                            anchors.centerIn: parent
                            text: (mediaCard.player && mediaCard.player.playbackState === 1) ? "󰏤" : "󰐊"
                            color: Colors.background; font.pixelSize: 22 
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.togglePlaying() }
                    }
                    Text { 
                        text: "󰒭"; color: Colors.text; font.pixelSize: 22
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.next() }
                    }
                    
                    Text { 
                        // 💡 Normalize the status to a lowercase string so it always matches reliably
                        property string currentLoop: mediaCard.player ? mediaCard.player.loopState.toString().toLowerCase() : "none"
                        
                        // 1 / track = 󰑘 (Loop Track) | 0 / 2 / playlist / none = 󰑖 (Standard Loop)
                        text: (currentLoop === "1" || currentLoop === "track") ? "󰑘" : "󰑖"
                        
                        // Highlight if it's not "none" (0)
                        color: (currentLoop === "0" || currentLoop === "none") ? Colors.text : Colors.workspaceactive
                        opacity: (currentLoop === "0" || currentLoop === "none") ? 0.5 : 1.0
                        
                        font.pixelSize: 18 
                        
                        MouseArea { 
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor 
                            
                            onClicked: {
                                if (!mediaCard.player) return;
                                
                                let nextState = "none";
                                
                                // None -> Playlist -> Track -> None
                                if (parent.currentLoop === "0" || parent.currentLoop === "none") {
                                    nextState = "playlist";
                                } else if (parent.currentLoop === "2" || parent.currentLoop === "playlist") {
                                    nextState = "track";
                                } else {
                                    nextState = "none";
                                }
                                
                                // 💡 playerctl strictly requires lowercase arguments
                                Quickshell.execDetached({ command: ["playerctl", "loop", nextState] });
                            }
                        }
                    }
                }

                Text {
                    id: timeLabel
                    Layout.fillWidth: true
                    color: Colors.text
                    opacity: 0.6
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // --- COLUMN 3: TOGGLES & CALENDAR ---
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            spacing: 15

            RowLayout {
                id: quickSettings
                Layout.fillWidth: true
                Layout.preferredHeight: 46 
                spacing: 10
                
                property bool btOn: true
                property bool caffeineOn: false
                property bool gameOn: false

                Rectangle { 
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
                    color: quickSettings.btOn ? Colors.workspaceactive : "transparent"
                    border.color: quickSettings.btOn ? "transparent" : Colors.border; border.width: quickSettings.btOn ? 0 : 2
                    
                    Text { anchors.centerIn: parent; text: quickSettings.btOn ? "󰂯" : "󰂲"; color: quickSettings.btOn ? Colors.background : Colors.text; opacity: quickSettings.btOn ? 1.0 : 0.7; font.pixelSize: 20 }
                    
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickSettings.btOn = !quickSettings.btOn;
                            Quickshell.execDetached({ command: ["rfkill", quickSettings.btOn ? "unblock" : "block", "bluetooth"] });
                        }
                    }
                }
                
                Rectangle { 
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
                    color: quickSettings.caffeineOn ? Colors.workspaceactive : "transparent"
                    border.color: quickSettings.caffeineOn ? "transparent" : Colors.border; border.width: quickSettings.caffeineOn ? 0 : 2
                    
                    Text { anchors.centerIn: parent; text: "󰅶"; color: quickSettings.caffeineOn ? Colors.background : Colors.text; opacity: quickSettings.caffeineOn ? 1.0 : 0.7; font.pixelSize: 20 }
                    
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickSettings.caffeineOn = !quickSettings.caffeineOn;
                            let cmd = quickSettings.caffeineOn ? "pkill -x hypridle || pkill -x swayidle" : "nohup hypridle >/dev/null 2>&1 & disown";
                            Quickshell.execDetached({ command: ["bash", "-c", cmd] });
                        }
                    }
                }
                
                Rectangle { 
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
                    color: quickSettings.gameOn ? Colors.workspaceactive : "transparent"
                    border.color: quickSettings.gameOn ? "transparent" : Colors.border; border.width: quickSettings.gameOn ? 0 : 2
                    
                    Text { anchors.centerIn: parent; text: "󰊴"; color: quickSettings.gameOn ? Colors.background : Colors.text; opacity: quickSettings.gameOn ? 1.0 : 0.7; font.pixelSize: 20 }
                    
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            quickSettings.gameOn = !quickSettings.gameOn;
                            Quickshell.execDetached({ command: ["bash", "-c", "bash ~/.config/Ax-Shell/scripts/gamemode.sh"] });
                        }
                    }
                }

                Process {
                    id: checkStatesProcess
                    command: ["bash", "-c", `
                        bt=$(rfkill list bluetooth | grep -qi 'Soft blocked: yes' && echo 'off' || echo 'on')
                        gm=$(bash ~/.config/Ax-Shell/scripts/gamemode.sh check 2>/dev/null)
                        [[ "$gm" == "t" ]] && game="on" || game="off"
                        
                        if pgrep -x "hypridle" >/dev/null || pgrep -x "swayidle" >/dev/null; then
                            caff="off"
                        else
                            caff="on"
                        fi
                        echo "$bt|$caff|$game"
                    `]
                    running: root.isOpen 
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = text.trim().split("|");
                            if (parts.length === 3) {
                                quickSettings.btOn = (parts[0] === "on");
                                quickSettings.caffeineOn = (parts[1] === "on");
                                quickSettings.gameOn = (parts[2] === "on");
                            }
                        }
                    }
                }
            }

            DashboardCalendar {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // --- COLUMN 4: SYSTEM STATS & NETWORK ---
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            spacing: 15

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.color: Colors.border
                border.width: 2
                radius: 20
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12
                    
                    Text {
                        Layout.fillWidth: true
                        text: "System Stats"
                        color: Colors.text
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // CPU Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "󰍛"; color: Colors.workspaceactive; font.pixelSize: 18 }
                        Rectangle {
                            Layout.fillWidth: true; height: 18; radius: 9; color: Colors.border
                            Rectangle { width: parent.width * (root.cpuUsage / 100); height: parent.height; radius: 9; color: Colors.workspaceactive }
                            Text { anchors.centerIn: parent; text: "CPU"; color: Colors.background; font.pixelSize: 10; font.weight: Font.Bold }
                        }
                        Text { text: root.cpuUsage + "%"; color: Colors.text; opacity: 0.8; font.pixelSize: 12; Layout.preferredWidth: 35 }
                    }

                    // GPU Row (RX 6600)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "󰢮"; color: Colors.workspaceactive; font.pixelSize: 18 }
                        Rectangle {
                            Layout.fillWidth: true; height: 18; radius: 9; color: Colors.border
                            Rectangle { width: parent.width * (root.gpuUsage / 100); height: parent.height; radius: 9; color: Colors.workspaceactive }
                            Text { anchors.centerIn: parent; text: "GPU"; color: Colors.background; font.pixelSize: 10; font.weight: Font.Bold }
                        }
                        Text { text: root.gpuUsage + "%"; color: Colors.text; opacity: 0.8; font.pixelSize: 12; Layout.preferredWidth: 35 }
                    }

                    // RAM Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "󰘚"; color: Colors.workspaceactive; font.pixelSize: 18 }
                        Rectangle {
                            Layout.fillWidth: true; height: 18; radius: 9; color: Colors.border
                            Rectangle { width: parent.width * (root.ramUsage / 100); height: parent.height; radius: 9; color: Colors.workspaceactive }
                            Text { anchors.centerIn: parent; text: "RAM"; color: Colors.background; font.pixelSize: 10; font.weight: Font.Bold }
                        }
                        Text { text: root.ramUsage + "%"; color: Colors.text; opacity: 0.8; font.pixelSize: 12; Layout.preferredWidth: 35 }
                    }

                    // Disk Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "󰋊"; color: Colors.workspaceactive; font.pixelSize: 18 }
                        Rectangle {
                            Layout.fillWidth: true; height: 18; radius: 9; color: Colors.border
                            Rectangle { width: parent.width * (root.diskUsage / 100); height: parent.height; radius: 9; color: Colors.workspaceactive }
                            Text { anchors.centerIn: parent; text: "Disk"; color: Colors.background; font.pixelSize: 10; font.weight: Font.Bold }
                        }
                        Text { text: root.diskUsage + "%"; color: Colors.text; opacity: 0.8; font.pixelSize: 12; Layout.preferredWidth: 35 }
                    }
                }
            }

            // Network Monitor Card
            Rectangle {
                id: netCard
                Layout.fillWidth: true
                Layout.preferredHeight: 130
                color: "transparent"
                border.color: Colors.border
                border.width: 2
                radius: 20
                
                property real upSpeed: 0
                property real downSpeed: 0
                property var lastBytes: [0, 0, Date.now()]
                property var history: [0, 0, 0, 0, 0, 0, 0, 0]

                Process {
                    id: netProc
                    command: ["python3", "-c", "
with open('/proc/net/dev', 'r') as f:
    for line in f:
        if 'eth0:' in line:
            parts = line.split()
            print(parts[1], parts[9])
            break
"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = text.trim().split(/\s+/);
                            if (parts.length === 2) {
                                let rx = parseInt(parts[0]) || 0;
                                let tx = parseInt(parts[1]) || 0;
                                let now = Date.now();
                                
                                let prevRx = netCard.lastBytes[0];
                                let prevTx = netCard.lastBytes[1];
                                let prevTime = netCard.lastBytes[2];
                                
                                if (prevRx > 0 && prevTime > 0) {
                                    let dt = (now - prevTime) / 1000.0;
                                    if (dt > 0) {
                                        let rxDiff = Math.max(0, rx - prevRx) * 8; // bits
                                        let txDiff = Math.max(0, tx - prevTx) * 8; // bits
                                        
                                        netCard.downSpeed = (rxDiff / dt) / 1000000; 
                                        netCard.upSpeed = (txDiff / dt) / 1000000;   
                                        
                                        let h = netCard.history;
                                        h.shift();
                                        h.push(netCard.downSpeed);
                                        netCard.history = h;
                                        netCanvas.requestPaint();
                                    }
                                }
                                netCard.lastBytes = [rx, tx, now];
                            }
                        }
                    }
                }

                Timer {
                    interval: 1000
                    running: root.isOpen
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        netProc.running = false;
                        Qt.callLater(() => {
                            if (root.isOpen) netProc.running = true;
                        });
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 5
                    
                    Text {
                        Layout.fillWidth: true
                        text: "Network Monitor"
                        color: Colors.text
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Canvas {
                            id: netCanvas
                            anchors.fill: parent
                            property color graphLine: Colors.workspaceactive
                            property color graphFill: Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.2)
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                
                                let h = netCard.history;
                                if (!h || h.length === 0) return;
                                
                                let maxVal = Math.max(...h, 0.5); 
                                let stepX = width / Math.max(1, h.length - 1);
                                
                                ctx.beginPath();
                                ctx.moveTo(0, height);
                                for (let i = 0; i < h.length; i++) {
                                    let x = i * stepX;
                                    let y = height - (h[i] / maxVal) * (height - 5);
                                    if (i === 0) ctx.lineTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.lineTo(width, height);
                                ctx.fillStyle = graphFill;
                                ctx.fill();
                                
                                ctx.beginPath();
                                for (let i = 0; i < h.length; i++) {
                                    let x = i * stepX;
                                    let y = height - (h[i] / maxVal) * (height - 5);
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = graphLine;
                                ctx.lineWidth = 2;
                                ctx.stroke();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "UP: " + (netCard.upSpeed < 1 ? Math.round(netCard.upSpeed * 1000) + " Kbps" : netCard.upSpeed.toFixed(1) + " Mbps"); color: Colors.text; opacity: 0.7; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text { text: "DOWN: " + (netCard.downSpeed < 1 ? Math.round(netCard.downSpeed * 1000) + " Kbps" : netCard.downSpeed.toFixed(1) + " Mbps"); color: Colors.text; opacity: 0.7; font.pixelSize: 11 }
                    }
                }
            }
        }

        // --- COLUMN 5: DUAL CAPSULE PODS WITH BACKGROUND FILL & ARC AUDIO ---
        ColumnLayout {
            Layout.preferredWidth: 64
            Layout.fillHeight: true
            spacing: 12

            // 1. Brightness Capsule Pod
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 22
                color: "transparent"
                border.color: Colors.border
                border.width: 2

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 2
                    width: parent.width - 4
                    height: (parent.height - 4) * (bSlider.value / 100)
                    radius: 20
                    color: Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15)
                    Behavior on height { NumberAnimation { duration: 100 } }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 44; height: 44; radius: 22
                        color: Colors.workspaceactive
                        Text { anchors.centerIn: parent; text: "󰃠"; color: Colors.background; font.pixelSize: 20 }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Slider {
                            id: bSlider
                            width: parent.height * 0.8
                            height: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            rotation: -90 
                            
                            from: 0; to: 100; stepSize: 1
                            
                            onMoved: {
                                let val = Math.round(value);
                                setBrightness.command = ["ddcutil", "setvcp", "10", val.toString()];
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    let delta = wheel.angleDelta.y > 0 ? 5 : -5;
                                    bSlider.value = Math.min(100, Math.max(0, bSlider.value + delta));
                                    setBrightness.command = ["ddcutil", "setvcp", "10", Math.round(bSlider.value).toString()];
                                    wheel.accepted = true;
                                }
                            }
                            
                            background: Rectangle {
                                x: bSlider.leftPadding; y: bSlider.topPadding + bSlider.availableHeight / 2 - height / 2
                                width: bSlider.availableWidth; height: 4; radius: 2; color: Colors.border 
                                Rectangle {
                                    width: bSlider.visualPosition * parent.width; height: parent.height
                                    color: Colors.workspaceactive; radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: bSlider.leftPadding + bSlider.visualPosition * (bSlider.availableWidth - width)
                                y: bSlider.topPadding + bSlider.availableHeight / 2 - height / 2
                                width: 12; height: 12; radius: 6; color: Colors.background
                                border.color: Colors.workspaceactive; border.width: 2
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(bSlider.value) + "%"
                        color: Colors.text
                        opacity: 0.7
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            // 2. Audio & Mic Capsule Pod (with Background Fill Effect)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: "transparent"
                border.color: Colors.border
                border.width: 2

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 2
                    width: parent.width - 4
                    height: (parent.height - 4) * ((AudioService.sink?.audio?.muted ? 0 : (AudioService.sink?.audio?.volume ?? 0)))
                    radius: 20
                    color: Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.15)
                    Behavior on height { NumberAnimation { duration: 100 } }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Item { Layout.fillHeight: true }

                    // Master Volume Button with Media Arc Style & Percentage
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 44; height: 44

                            Rectangle {
                                anchors.centerIn: parent
                                width: 38; height: 38; radius: 19
                                color: AudioService.sink?.audio?.muted ? "transparent" : Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.2)
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: AudioService.sink?.audio?.muted ? "󰝟" : "󰕾"
                                    color: Colors.text
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioService.toggleMute()
                                    onWheel: (wheel) => {
                                        if (!AudioService.sink?.audio) return;
                                        let currentVol = AudioService.sink.audio.volume;
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        AudioService.sink.audio.volume = Math.min(1.0, Math.max(0.0, currentVol + delta));
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            Canvas {
                                id: volArcCanvas
                                anchors.fill: parent
                                property color trackColor: Colors.border
                                property color progressColor: Colors.workspaceactive
                                property real progress: AudioService.sink?.audio?.volume ?? 0

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (AudioService.sink?.audio?.muted) return;

                                    let cx = width / 2;
                                    let cy = height / 2;
                                    let r = width / 2 - 2;

                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, Math.PI * 0.75, Math.PI * 0.25);
                                    ctx.strokeStyle = trackColor;
                                    ctx.lineWidth = 3;
                                    ctx.lineCap = "round";
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, Math.PI * 0.75, Math.PI * 0.75 + (progress * Math.PI * 1.5));
                                    ctx.strokeStyle = progressColor;
                                    ctx.lineWidth = 3;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }
                                Connections {
                                    target: AudioService.sink?.audio
                                    function onVolumeChanged() { volArcCanvas.requestPaint() }
                                    function onMutedChanged() { volArcCanvas.requestPaint() }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                            color: Colors.text
                            opacity: 0.7
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    // Microphone Button with Media Arc Style & Percentage
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 44; height: 44

                            Rectangle {
                                anchors.centerIn: parent
                                width: 38; height: 38; radius: 19
                                color: AudioService.source?.audio?.muted ? "transparent" : Qt.rgba(Colors.workspaceactive.r, Colors.workspaceactive.g, Colors.workspaceactive.b, 0.2)
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: AudioService.source?.audio?.muted ? "󰍭" : "󰍬"
                                    color: Colors.text
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioService.toggleMicMute()
                                    onWheel: (wheel) => {
                                        if (!AudioService.source?.audio) return;
                                        let currentVol = AudioService.source.audio.volume;
                                        let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                        AudioService.source.audio.volume = Math.min(1.0, Math.max(0.0, currentVol + delta));
                                        wheel.accepted = true;
                                    }
                                }
                            }

                            Canvas {
                                id: micArcCanvas
                                anchors.fill: parent
                                property color trackColor: Colors.border
                                property color progressColor: Colors.workspaceactive
                                property real progress: AudioService.source?.audio?.volume ?? 0

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (AudioService.source?.audio?.muted) return;

                                    let cx = width / 2;
                                    let cy = height / 2;
                                    let r = width / 2 - 2;

                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, Math.PI * 0.75, Math.PI * 0.25);
                                    ctx.strokeStyle = trackColor;
                                    ctx.lineWidth = 3;
                                    ctx.lineCap = "round";
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, Math.PI * 0.75, Math.PI * 0.75 + (progress * Math.PI * 1.5));
                                    ctx.strokeStyle = progressColor;
                                    ctx.lineWidth = 3;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }
                                Connections {
                                    target: AudioService.source?.audio
                                    function onVolumeChanged() { micArcCanvas.requestPaint() }
                                    function onMutedChanged() { micArcCanvas.requestPaint() }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round((AudioService.source?.audio?.volume ?? 0) * 100) + "%"
                            color: Colors.text
                            opacity: 0.7
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    Process {
        id: getBrightness
        command: ["python3", "-c", "
import subprocess
try:
    res = subprocess.run(['ddcutil', 'getvcp', '10', '--brief'], capture_output=True, text=True, timeout=1)
    parts = res.stdout.strip().split()
    if len(parts) >= 4:
        print(int(parts[3]))
    else:
        print(0)
except Exception:
    print(0)
"]
        running: root.isOpen 
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(text.trim());
                if (!isNaN(val)) {
                    bSlider.value = val;
                }
            }
        }
    }

    Process {
        id: setBrightness
        running: command.length > 0
    }
}