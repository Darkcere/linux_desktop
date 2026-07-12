import Quickshell
import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: toolsWindow
    
    property bool isOpen: false
    signal closeRequested()

    property int selectedIndex: 0
    property string currentMenuId: "menu_main"
    
    // Status trackers for the dynamic tags
    property string statGamemode: "[Checking...]"
    property string statRec: "[Checking...]"
    property string statPrivacy: "[Checking...]"
    property string statLayoutWs: ""
    property string statLayoutGen: ""
    property string statPomodoro: "[Checking...]"
    
    // Removed the broken JS getters. Kept the lightweight fast array.
    readonly property var menuData: {
        "menu_main": [
            { name: "Game Mode", iconStr: "", action: "gamemode" },
            { name: "Toggle HDR", iconStr: "󰹑", action: "hdr" },
            { name: "Layouts", iconStr: "󰕰", action: "menu_layouts" },
            { name: "Screenshare Privacy", iconStr: "󰈈", action: "privacy" },
            { name: "Screenshot Menu", iconStr: "", action: "menu_screenshot" },
            { name: "Recorder", iconStr: "󰑋", action: "screenrecord" },
            { name: "Open Recordings", iconStr: "", action: "open_rec" },
            { name: "OCR", iconStr: "󰊄", action: "ocr" },
            { name: "Color Picker", iconStr: "", action: "menu_colorpicker" },
            { name: "Pomodoro", iconStr: "⏱", action: "pomodoro" }
        ],
        "menu_layouts": [
            { name: "Dwindle", iconStr: "󰕰", action: "lay_dwindle" },
            { name: "Scrolling", iconStr: "󰕰", action: "lay_scrolling" },
            { name: "Master", iconStr: "󰕰", action: "lay_master" },
            { name: "Monocle", iconStr: "󰕰", action: "lay_monocle" },
            { name: "Set Current to General", iconStr: "󰕰", action: "lay_general" },
            { name: "Go Back", iconStr: "", action: "menu_main" }
        ],
        "menu_screenshot": [
            { name: "Open Folder", iconStr: "", action: "ss_folder" },
            { name: "Region", iconStr: "", action: "ss_region" },
            { name: "Window", iconStr: "", action: "ss_window" },
            { name: "Fullscreen", iconStr: "", action: "ss_full" },
            { name: "Go Back", iconStr: "", action: "menu_main" }
        ],
        "menu_colorpicker": [
            { name: "HEX", iconStr: "", action: "cp_hex" },
            { name: "RGB", iconStr: "", action: "cp_rgb" },
            { name: "HSV", iconStr: "", action: "cp_hsv" },
            { name: "Go Back", iconStr: "", action: "menu_main" }
        ]
    }
    
    property var activeModel: []

    onIsOpenChanged: {
        if (isOpen) {
            currentMenuId = "menu_main";
            selectedIndex = 0;
            activeModel = menuData["menu_main"];
            toolsWindow.forceActiveFocus();
            fetchStatsProcess.running = true; 
        }
    }

    // --- LIVE STATUS FETCHER ---
    Process {
        id: fetchStatsProcess
        command: ["bash", "-c", `
            gamemode_char=$(bash ~/.config/Ax-Shell/scripts/gamemode.sh check 2>/dev/null)
            [[ "$gamemode_char" == "t" ]] && gamemode="[Enabled]" || gamemode="[Disabled]"
            
            pgrep -f "[g]pu-screen-recorder" >/dev/null && rec="[LIVE]" || rec="[REC]"
            pgrep -f "[p]omodoro.sh" >/dev/null && pomo="[Timer On]" || pomo="[Timer Off]"
            
            privacy_prop=$(hyprctl getprop active no_screen_share 2>/dev/null)
            if [[ "$privacy_prop" == *"int: 1"* || "$privacy_prop" == *"true"* ]]; then
                privacy="[HIDDEN]"
            else
                privacy="[VISIBLE]"
            fi
            
            lay_ws=$(hyprctl activeworkspace | awk '/tiledLayout:/ {print $2}')
            lay_gen=$(hyprctl getoption general:layout -j | jq -r '.str')
            
            cat <<EOF
            {
                "gamemode": "$gamemode",
                "rec": "$rec",
                "privacy": "$privacy",
                "layout_ws": "$lay_ws",
                "layout_gen": "$lay_gen",
                "pomodoro": "$pomo"
            }
EOF
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    toolsWindow.statGamemode = data.gamemode;
                    toolsWindow.statRec = data.rec;
                    toolsWindow.statPrivacy = data.privacy;
                    toolsWindow.statLayoutWs = data.layout_ws;
                    toolsWindow.statLayoutGen = data.layout_gen;
                    toolsWindow.statPomodoro = data.pomodoro;
                } catch(e) {
                    console.log("Tools.qml JSON parse error: " + e);
                }
            }
        }
    }

    // --- MENU LOGIC ---
    function executeSelected(index) {
        if (index < 0 || index >= activeModel.length) return;
        
        let action = activeModel[index].action;
        let scriptsDir = "/home/duarte/.config/Ax-Shell/scripts/";
        
        if (action.startsWith("menu_")) {
            toolsWindow.currentMenuId = action;
            toolsWindow.selectedIndex = 0;
            toolsWindow.activeModel = toolsWindow.menuData[action];
            return;
        }

        let cmd = "";
        
        switch (action) {
            case "gamemode": cmd = `bash ${scriptsDir}gamemode.sh &`; break;
            case "hdr": 
                cmd = `preset=$(hyprctl monitors all | awk -F': ' '/colorManagementPreset/ {print $2; exit}'); if [[ "$preset" == "hdr" ]]; then hyprctl keyword monitor ",highrr,auto,1"; else hyprctl keyword monitor ",highrr,auto,1,bitdepth,10,cm,hdr,sdrbrightness,5"; fi`; 
                break;
            case "privacy": cmd = `hyprctl dispatch setprop active no_screen_share toggle`; break;
            case "screenrecord": cmd = `nohup bash ${scriptsDir}screenrecord.sh > /dev/null 2>&1 & disown`; break;
            case "open_rec": cmd = `xdg-open "\${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings" &`; break;
            case "ocr": cmd = `sleep 0.3; bash ${scriptsDir}ocr.sh &`; break;
            case "pomodoro": cmd = `nohup bash ${scriptsDir}pomodoro.sh > /dev/null 2>&1 & disown`; break;
            
            case "lay_dwindle": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:dwindle`; break;
            case "lay_scrolling": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:scrolling`; break;
            case "lay_master": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:master`; break;
            case "lay_monocle": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:monocle`; break;
            case "lay_general": cmd = `hyprctl keyword general:layout "${toolsWindow.statLayoutWs}"`; break;
            
            case "ss_folder": cmd = `xdg-open "\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots" &`; break;
            case "ss_region": cmd = `sleep 0.3; bash ${scriptsDir}screenshot.sh s &`; break;
            case "ss_window": cmd = `bash ${scriptsDir}screenshot.sh w &`; break;
            case "ss_full": cmd = `bash ${scriptsDir}screenshot.sh p &`; break;
            
            case "cp_hex": cmd = `sleep 0.3; bash ${scriptsDir}hyprpicker.sh -hex`; break;
            case "cp_rgb": cmd = `sleep 0.3; bash ${scriptsDir}hyprpicker.sh -rgb`; break;
            case "cp_hsv": cmd = `sleep 0.3; bash ${scriptsDir}hyprpicker.sh -hsv`; break;
        }

        if (cmd !== "") {
            console.debug("Tools executing: " + cmd);
            Quickshell.execDetached({ command: ["bash", "-c", cmd] });
        }
        
        toolsWindow.closeRequested();
    }

    // --- INJECTED UI ---
    
    focus: true
    Keys.onEscapePressed: (event) => {
        event.accepted = true;
        if (toolsWindow.currentMenuId !== "menu_main") {
            toolsWindow.currentMenuId = "menu_main";
            toolsWindow.selectedIndex = 0;
            toolsWindow.activeModel = toolsWindow.menuData["menu_main"];
        } else {
            toolsWindow.closeRequested();
        }
    }
    Keys.onDownPressed: (event) => {
        event.accepted = true;
        toolsWindow.selectedIndex = Math.min(toolsWindow.selectedIndex + 1, activeModel.length - 1);
        toolsList.positionViewAtIndex(toolsWindow.selectedIndex, ListView.Contain);
    }
    Keys.onUpPressed: (event) => {
        event.accepted = true;
        toolsWindow.selectedIndex = Math.max(toolsWindow.selectedIndex - 1, 0);
        toolsList.positionViewAtIndex(toolsWindow.selectedIndex, ListView.Contain);
    }
    Keys.onReturnPressed: (event) => {
        event.accepted = true;
        toolsWindow.executeSelected(toolsWindow.selectedIndex);
    }

    ListView {
        id: toolsList
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        model: toolsWindow.activeModel
        currentIndex: toolsWindow.selectedIndex
        spacing: 10

        delegate: Rectangle {
            width: toolsList.width
            height: 50
            radius: 8
            
            color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.workspaceactive : Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1)
            border.color: Colors.border
            border.width: 1
            
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15
                
                Text {
                    text: modelData.iconStr
                    font.pixelSize: 18
                    color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.text
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                
                Text {
                    text: modelData.name
                    font.pixelSize: 15
                    font.bold: true
                    color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.text
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // 🚀 THE FIX: QML dynamically evaluates this natively based on the action ID!
            Text {
                text: {
                    if (modelData.action === "gamemode") return toolsWindow.statGamemode;
                    if (modelData.action === "screenrecord") return toolsWindow.statRec;
                    if (modelData.action === "privacy") return toolsWindow.statPrivacy;
                    if (modelData.action === "pomodoro") return toolsWindow.statPomodoro;
                    if (modelData.action === "menu_layouts") {
                        return toolsWindow.statLayoutWs ? ("Ws: [" + toolsWindow.statLayoutWs + "] | Gen: [" + toolsWindow.statLayoutGen + "]") : "";
                    }
                    return "";
                }
                font.pixelSize: 13
                font.bold: true
                color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.workspaceactive
                opacity: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? 0.9 : 0.7
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: toolMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: toolsWindow.executeSelected(index)
                onEntered: toolsWindow.selectedIndex = index
            }
        }
    }
}