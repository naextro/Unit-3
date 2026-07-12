import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "widgets"
import "components"
import "settings"

ShellRoot {
    id: root

    // ── NOTIFICATIONS ──
    Notifications {}

    // ── CONTROLCENTER ──
    ControlCenter {}


    // ── VOLUMEBAR ──
    VolumeBar {}
    // ── BRIGHTNESSBAR ──
    BrightnessBar {}
    // ── PLAYERCTL ──
    property bool   playerVisible: false   // one-way mirror of Player's own `shown`, for gating only — never drives the toggle
    property bool   playerOnTop:   false
    property string mpTitle:    "END OF EVANGELION"
    property string mpArtist:   "NEON GENESIS // ANNO"
    property string mpCoverUrl: ""
    property bool   mpPlaying:  false
    property real   mpPosition: 0
    property real   mpLength:   341

    // Long-lived, event-driven MPRIS stream — no polling fork.
    // --follow keeps this process alive and only emits on actual
    // metadata/status change (track change, play/pause, seek).
    Process {
        id: playerctlMeta
        command: ["playerctl","metadata","--follow","--format",
                  "{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}|{{position}}|{{mpris:length}}"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                if (p.length >= 4) {
                    if (p[0]) root.mpTitle    = p[0]
                    if (p[1]) root.mpArtist   = p[1]
                    root.mpCoverUrl = p[2] || ""
                    root.mpPlaying  = (p[3] === "Playing")
                    root.mpPosition = parseFloat(p[4] || "0") / 1000000
                    root.mpLength   = Math.max(1, parseFloat(p[5] || "341000000") / 1000000)
                }
            }
        }
    }
    Process { id: pcPlay; command: ["playerctl","play-pause"]; running: false }
    Process { id: pcNext; command: ["playerctl","next"];       running: false }
    Process { id: pcPrev; command: ["playerctl","previous"];   running: false }

    // Local-only progress ticker — no process fork, only runs while the
    // player panel is actually open AND something is playing.
    Timer {
        id: positionTicker
        interval: 1000
        running: root.playerVisible && root.mpPlaying
        repeat:  true
        onTriggered: root.mpPosition = Math.min(root.mpLength, root.mpPosition + 1)
    }

    property string currentUser: "user"
    Process {
        id: getUserProc; command:["sh","-c","echo $USER"]; running:true
        stdout: SplitParser { onRead: data => { var u=data.trim(); if(u!=="") root.currentUser=u } }
    }

    Component.onCompleted: {
        Qt.createQmlObject(
            'import Quickshell.Io; Process{command:["sh","-c","rm -f /tmp/qs-menu /tmp/qs-toggle /tmp/qs-front"];running:true}',
            root, "cleanup")
    }

    property string menuActiveMonitor: Quickshell.screens.length>0 ? Quickshell.screens[0].name : ""
    signal menuFireToggle()

    Process {
        id: detectMonitor
        command: ["/bin/sh", Qt.resolvedUrl("active-monitor.sh").toString().replace("file://","")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim()
                if (name !== "") root.menuActiveMonitor = name
                root.menuFireToggle()
            }
        }
    }

    // ── Shell-level IPC — replaces the /tmp file-polling entirely ──
    // qs ipc call shell toggleFront   → bring player above other windows
    // qs ipc call shell toggleMenu    → open/close the menu
    // Player's own toggle stays self-contained: qs ipc call player toggle
    IpcHandler {
        target: "shell"
        function toggleFront(): void { root.playerOnTop = !root.playerOnTop }
        function toggleMenu(): void  { detectMonitor.running = true }
    }


    // ── MENU ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen:modelData
            anchors.top:true;anchors.left:true;anchors.right:true;anchors.bottom:true
            exclusionMode:ExclusionMode.Ignore
            aboveWindows:menuItem.menuOpen||menuItem.wipeHideRunning
            color:"transparent"
            WlrLayershell.keyboardFocus:menuItem.menuOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
            implicitWidth:modelData.width;implicitHeight:modelData.height
            Menu{id:menuItem;anchors.fill:parent;screenW:modelData.width;screenH:modelData.height}
            Connections{target:root;function onMenuFireToggle(){
                if(root.menuActiveMonitor!==modelData.name)return
                if(menuItem.menuOpen)menuItem.closeMenu();else menuItem.openMenu()
            }}
        }
    }


    // ── PLAYER ──
    Variants {
        model:Quickshell.screens
        PanelWindow {
            required property var modelData;screen:modelData
            anchors.top:true;anchors.right:true
            margins.top:Math.round(modelData.height*Settings.playerPositionY);margins.right:20
            exclusionMode:ExclusionMode.Ignore;aboveWindows: playerItem.shown || playerItem.animRunning;color:"transparent"
            implicitWidth:Settings.playerWidth;implicitHeight:playerItem.implicitHeight
            Player{id:playerItem;anchors.fill:parent
                mpTitle:root.mpTitle;mpArtist:root.mpArtist;mpCoverUrl:root.mpCoverUrl
                mpPlaying:root.mpPlaying;mpPosition:root.mpPosition;mpLength:root.mpLength
                onPlayPause:pcPlay.running=true;onNextTrack:pcNext.running=true;onPrevTrack:pcPrev.running=true}
            // ONE-WAY only: Player toggles itself via its own IpcHandler (qs ipc call player toggle).
            // This just mirrors the resulting state up to root for the position-ticker gate —
            // it must never call playerItem.toggleVisible() or you get a double-toggle loop.
            Connections{target:playerItem;function onShownChanged(){root.playerVisible=playerItem.shown}}
        }
    }

    // ── COMPANIONS ──
    Variants {
        model:Settings.companionsEnabled ? Quickshell.screens : []
        PanelWindow {
            required property var modelData;screen:modelData
            anchors.bottom:true;anchors.right:true;margins.right:Settings.companionsMarginRight
            exclusionMode:ExclusionMode.Ignore;color:"transparent"
            implicitWidth:Settings.companionsSpriteSize+58;implicitHeight:compItem.implicitHeight
            Companions{id:compItem;anchors.fill:parent}
            }
        }

    // ── AI PANEL ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData; screen: modelData
            anchors.top: true; anchors.left: true; anchors.right: true; anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: aiItem.shown || aiItem.animRunning
            color: "transparent"
            WlrLayershell.keyboardFocus: (aiItem.shown && (!aiItem.pinned || aiItem.hovered))
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            implicitWidth: modelData.width; implicitHeight: modelData.height

            mask: Region {
                x: aiItem.pinned ? aiItem.panelX : 0
                y: aiItem.pinned ? aiItem.panelY : 0
                width: aiItem.pinned ? aiItem.panelWidth : modelData.width
                height: aiItem.pinned ? aiItem.panelHeight : modelData.height
            }

            AiPanel {
                id: aiItem; anchors.fill: parent
                screenW: modelData.width; screenH: modelData.height
            }
        }
    }
    }