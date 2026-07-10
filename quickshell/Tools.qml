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

    ListModel { id: toolModel }

    onIsOpenChanged: {
        if (isOpen) {
            currentMenuId = "menu_main";
            selectedIndex = 0;
            focusCatcher.forceActiveFocus();
            fetchStatsProcess.running = true; // Fetch live statuses instantly
            loadMenu("menu_main");
        }
    }

    // --- 🚀 LIVE STATUS FETCHER ---
    Process {
        id: fetchStatsProcess
        command: ["bash", "-c", `
            gamemode_char=$(bash ~/.config/Ax-Shell/scripts/gamemode.sh check 2>/dev/null)
            [[ "$gamemode_char" == "t" ]] && gamemode="[Enabled]" || gamemode="[Disabled]"
            
            # THE BRACKET TRICK: Prevents pgrep from matching this exact bash command string!
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
                    
                    // Refresh if currently on main menu
                    if (toolsWindow.currentMenuId === "menu_main") {
                        toolsWindow.loadMenu("menu_main");
                    }
                } catch(e) {
                    console.log("Tools.qml JSON parse error: " + e);
                }
            }
        }
    }

    // --- MENU DATA STRUCTURE ---
    function loadMenu(menuId) {
        toolsWindow.currentMenuId = menuId;
        toolsWindow.selectedIndex = 0;
        toolModel.clear();
        
        let items = [];
        
        if (menuId === "menu_main") {
            items = [
                { name: "Game Mode", status: statGamemode, iconStr: "", action: "gamemode" },
                { name: "Toggle HDR", status: "", iconStr: "󰹑", action: "hdr" },
                { name: "Layouts", status: statLayoutWs ? ("Ws: [" + statLayoutWs + "] | Gen: [" + statLayoutGen + "]") : "", iconStr: "󰕰", action: "menu_layouts" },
                { name: "Screenshare Privacy", status: statPrivacy, iconStr: "󰈈", action: "privacy" },
                { name: "Screenshot Menu", status: "", iconStr: "", action: "menu_screenshot" },
                { name: "Recorder", status: statRec, iconStr: "󰑋", action: "screenrecord" },
                { name: "Open Recordings", status: "", iconStr: "", action: "open_rec" },
                { name: "OCR", status: "", iconStr: "󰊄", action: "ocr" },
                { name: "Color Picker", status: "", iconStr: "", action: "menu_colorpicker" },
                { name: "Pomodoro", status: statPomodoro, iconStr: "⏱", action: "pomodoro" }
            ];
        } else if (menuId === "menu_layouts") {
            items = [
                { name: "Dwindle", status: "", iconStr: "󰕰", action: "lay_dwindle" },
                { name: "Scrolling", status: "", iconStr: "󰕰", action: "lay_scrolling" },
                { name: "Master", status: "", iconStr: "󰕰", action: "lay_master" },
                { name: "Monocle", status: "", iconStr: "󰕰", action: "lay_monocle" },
                { name: "Set Current to General", status: "", iconStr: "󰕰", action: "lay_general" },
                { name: "Go Back", status: "", iconStr: "", action: "menu_main" }
            ];
        } else if (menuId === "menu_screenshot") {
            items = [
                { name: "Open Folder", status: "", iconStr: "", action: "ss_folder" },
                { name: "Region", status: "", iconStr: "", action: "ss_region" },
                { name: "Window", status: "", iconStr: "", action: "ss_window" },
                { name: "Fullscreen", status: "", iconStr: "", action: "ss_full" },
                { name: "Go Back", status: "", iconStr: "", action: "menu_main" }
            ];
        } else if (menuId === "menu_colorpicker") {
            items = [
                { name: "HEX", status: "", iconStr: "", action: "cp_hex" },
                { name: "RGB", status: "", iconStr: "", action: "cp_rgb" },
                { name: "HSV", status: "", iconStr: "", action: "cp_hsv" },
                { name: "Go Back", status: "", iconStr: "", action: "menu_main" }
            ];
        }
        
        for (let i = 0; i < items.length; i++) {
            toolModel.append(items[i]);
        }
    }

    // --- ACTION EXECUTOR ---
    function executeSelected(index) {
        if (index < 0 || index >= toolModel.count) return;
        
        let action = toolModel.get(index).action;
        let scriptsDir = "/home/duarte/.config/Ax-Shell/scripts/";
        
        // Handle Submenus instantly
        if (action.startsWith("menu_")) {
            loadMenu(action);
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
            case "ocr": cmd = `bash ${scriptsDir}ocr.sh &`; break;
            case "pomodoro": cmd = `nohup bash ${scriptsDir}pomodoro.sh > /dev/null 2>&1 & disown`; break;
            
            // Layouts
            case "lay_dwindle": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:dwindle`; break;
            case "lay_scrolling": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:scrolling`; break;
            case "lay_master": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:master`; break;
            case "lay_monocle": cmd = `hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:monocle`; break;
            case "lay_general": cmd = `hyprctl keyword general:layout "${toolsWindow.statLayoutWs}"`; break;
            
            // Screenshots
            case "ss_folder": cmd = `xdg-open "\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots" &`; break;
            case "ss_region": cmd = `sleep 0.2; bash ${scriptsDir}screenshot.sh s &`; break;
            case "ss_window": cmd = `bash ${scriptsDir}screenshot.sh w &`; break;
            case "ss_full": cmd = `bash ${scriptsDir}screenshot.sh p &`; break;
            
            // Color Picker
            case "cp_hex": cmd = `sleep 0.2; bash ${scriptsDir}hyprpicker.sh -hex`; break;
            case "cp_rgb": cmd = `sleep 0.2; bash ${scriptsDir}hyprpicker.sh -rgb`; break;
            case "cp_hsv": cmd = `sleep 0.2; bash ${scriptsDir}hyprpicker.sh -hsv`; break;
        }

        if (cmd !== "") {
            console.debug("Tools executing: " + cmd);
            Quickshell.execDetached({ command: ["bash", "-c", cmd] });
        }
        
        toolsWindow.closeRequested();
    }

    // --- INJECTED UI ---
    
    // Invisible item to catch keyboard navigation
    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: (event) => {
            event.accepted = true;
            if (toolsWindow.currentMenuId !== "menu_main") {
                toolsWindow.loadMenu("menu_main");
            } else {
                toolsWindow.closeRequested();
            }
        }
        Keys.onDownPressed: (event) => {
            event.accepted = true;
            toolsWindow.selectedIndex = Math.min(toolsWindow.selectedIndex + 1, toolModel.count - 1);
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
    }

    ListView {
        id: toolsList
        anchors.fill: parent
        anchors.margins: 20
        clip: true
        model: toolModel
        currentIndex: toolsWindow.selectedIndex
        spacing: 10

        delegate: Rectangle {
            width: toolsList.width
            height: 50
            radius: 8
            
            // Unified styling matching Apps/Clipboard
            color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.workspaceactive : Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1)
            border.color: Colors.border
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15
                
                Text {
                    text: model.iconStr
                    font.pixelSize: 18
                    color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: model.name
                    font.pixelSize: 15
                    font.bold: true
                    color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.text
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Right-aligned status text
            Text {
                text: model.status
                font.pixelSize: 13
                font.bold: true
                color: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? Colors.background : Colors.workspaceactive
                opacity: (toolMouseArea.containsMouse || toolsList.currentIndex === index) ? 0.9 : 0.7
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
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