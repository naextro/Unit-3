import QtQuick
import Quickshell.Io
import "../components"
import "../settings"

Item {
    id: root
    // Reference speed taken from the ticker (px/ms) — used to derive the
    // title/artist scroll speed at 0.5x (i.e. half as fast)
    readonly property real tickerSpeed: (pw + ticker.implicitWidth) / 22000
    // ── Shorthand Settings (global scale) ──
    readonly property int  pw:      Settings.playerWidth
    readonly property real sc:      Settings.scale
    readonly property int  coverSz: Math.round(pw * 100/320)
    function s(px) { return Math.round(px * sc) }

    // ── playerctl bindings from shell.qml ──
    property string mpTitle:    "END OF EVANGELION"
    property string mpArtist:   "NEON GENESIS // ANNO"
    property string mpCoverUrl: ""
    property bool   mpPlaying:  false
    property real   mpPosition: 0
    property real   mpLength:   341

    signal playPause
    signal nextTrack
    signal prevTrack

    property bool   shown:    false
    property string clockStr: "--:--"
    property bool   expOpen:  false
    readonly property bool animRunning: hideAnim.running || revealAnim.running

    // Fixed width 320, height = content
    implicitWidth:  pw
    implicitHeight: wipeHost.height

    // ──────────────────────────────────────────────────────────────
    // WIPE HOST — clipped Item containing curtain + content as siblings
    // ──────────────────────────────────────────────────────────────
    Item {
        id:      wipeHost
        width:   pw
        height:  content.implicitHeight
        clip:    true
        x:       pw+2          // starts off-screen to the right (hidden)
        opacity: 1
        visible: false          // invisible at startup

        // ── CONTENT (actual player) ──
        Item {
            id:      content
            width:   pw
            implicitHeight: playerCol.implicitHeight

            // Conditional background — controlled by Settings.playerBackground
            Rectangle {
                anchors.fill: parent
                color:        Settings.playerBackground ? Settings.playerBgColor : "transparent"
                visible:      true
            }

            Column {
                id:    playerCol
                width: pw

                // Top line — sepia gradient
                Rectangle {
                    width: pw;  height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: Qt.rgba(200/255,184/255,154/255,0.5) }
                        GradientStop { position: 0.8; color: Qt.rgba(200/255,184/255,154/255,0.5) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Scrolling ticker
                Item {
                    width: pw;  height: s(14); clip: true
                    Text {
                        id:   ticker
                        text: "NR-2B // " + root.mpArtist + " // " + root.mpTitle
                              + " // LOSSLESS 48kHz/24bit // NOW PLAYING //\u00a0"
                        font.family: "Share Tech Mono"
                        font.pixelSize: s(8)
                        font.letterSpacing: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.2)
                        y: 3
                        NumberAnimation on x {
                            from: 320; to: -ticker.implicitWidth
                            duration: 22000; loops: Animation.Infinite; running: root.shown
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.06)
                    }
                }

                // ── COVER ROW ──
                Item {
                    width: pw;  height: coverSz

                    // Bottom border
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.07)
                    }

                    // Cover 100×100 — 32×32 grayscale grid
                    Item {
                        id:     coverArea
                        width:  coverSz; height: coverSz; clip: true

                        // Brush state — declared before the Canvases that reference them
                        property var hoverIntensity: new Array(32*32).fill(0)
                        property var hoverR:         new Array(32*32).fill(200)
                        property var hoverG:         new Array(32*32).fill(184)
                        property var hoverB:         new Array(32*32).fill(154)

                        // Gray cover canvas — drawGray + drawBlocky for transition
                        Canvas {
                            id:     coverMain
                            width:  coverSz; height: coverSz
                            smooth: false

                            property var  imgPixels:     null
                            property var  nextImgPixels: null  // pixels waiting during transition
                            property int  blockStep:     0     // transition step 0=normal
                            

                            onPaint: {
                                var ctx  = getContext("2d")
                                var GRID = 32, SZ = 100
                                var CELL = 100.0 / 32.0
                                ctx.clearRect(0, 0, SZ, SZ)

                                if (!imgPixels) {
                                    // procedural gray placeholder
                                    var seed = root.mpTitle.length * 1234567 + root.mpArtist.length * 89 + 42
                                    function rand() { seed=(seed*16807+0)%2147483647; return(seed-1)/2147483646 }
                                    for (var r=0; r<GRID; r++) for (var cc=0; cc<GRID; cc++) {
                                        var n=rand(); var dx=(cc-GRID/2)/(GRID/2); var dy=(r-GRID/2)/(GRID/2)
                                        var d=Math.sqrt(dx*dx+dy*dy)
                                        var v=Math.max(0,Math.min(255,(1-d*0.55)*210+n*70-30))
                                        ctx.fillStyle="rgb("+Math.round(v)+","+Math.round(v)+","+Math.round(v)+")"
                                        ctx.fillRect(Math.floor(cc*CELL),Math.floor(r*CELL),Math.floor(CELL)-1,Math.floor(CELL)-1)
                                    }
                                    return
                                }

                                // Block size according to transition step
                                var bs
                                if (blockStep === 0) {
                                    // Normal: 32×32 grid
                                    bs = Math.floor(CELL)
                                } else {
                                    bs = Math.floor(CELL) + blockStep
                                }
                                bs = Math.max(1, bs)

                                var src = imgPixels
                                var cols = Math.ceil(SZ / bs)
                                var rows = Math.ceil(SZ / bs)
                                for (var row=0; row<rows; row++) for (var col=0; col<cols; col++) {
                                    var sx  = Math.min(col*bs + Math.floor(bs/2), SZ-1)
                                    var sy  = Math.min(row*bs + Math.floor(bs/2), SZ-1)
                                    var idx = (sy*SZ + sx)*4
                                    var lum = 0.299*src[idx] + 0.587*src[idx+1] + 0.114*src[idx+2]
                                    var gv  = Math.round(Math.min(255, Math.max(0, (lum-10)*(255/235))))
                                    ctx.fillStyle = "rgb("+gv+","+gv+","+gv+")"
                                    ctx.fillRect(col*bs, row*bs, bs-1, bs-1)
                                }
                            }

                            Component.onCompleted: requestPaint()

                            Connections {
                                target: root
                                function onMpTitleChanged() {
                                    if (!coverMain.imgPixels) coverMain.requestPaint()
                                }
                            }
                        }

                        // Blocky transition timer — 12 steps of 30ms each
                        // Identical to transitionCover() in the source HTML JS
                        // CELL=3.125 → steps 0-5 grow, step 6 swap, 7-12 shrink
                        Timer {
                            id:       blockTimer
                            interval: 30
                            repeat:   true
                            running:  false
                            property int step: 0
                            property int steps: 12

                            onTriggered: {
                                var CELL = 100.0 / 32.0
                                step++
                                if (step < steps/2) {
                                    // Phase 1: grow the blocks (zoom out)
                                    coverMain.blockStep = Math.floor(step * 3)
                                    coverMain.requestPaint()
                                } else if (step === Math.floor(steps/2)) {
                                    // Midpoint: swap to new image
                                    if (coverMain.nextImgPixels) {
                                        coverMain.imgPixels = coverMain.nextImgPixels
                                        coverMain.nextImgPixels = null
                                    }
                                } else {
                                    // Phase 2: shrink the blocks (zoom back in)
                                    coverMain.blockStep = Math.max(0, Math.floor((steps - step) * 3))
                                    coverMain.requestPaint()
                                }

                                if (step >= steps) {
                                    running = false
                                    step = 0
                                    coverMain.blockStep = 0
                                    coverMain.requestPaint()
                                }
                            }
                        }

                        // Visible image for grabToImage
                        Image {
                            id:       coverSrc
                            width:    coverSz; height: coverSz
                            visible:  true; opacity: 0  // visible but transparent for grabToImage
                            smooth:   false
                            fillMode: Image.PreserveAspectCrop
                            z:        -1

                            onStatusChanged: {
                                if (status !== Image.Ready) return
                                // grabToImage extracts pixels into a canvas
                                grabToImage(function(result) {
                                    extractCanvas.grabResult = result
                                    extractCanvas.requestPaint()
                                }, Qt.size(100, 100))
                            }
                        }

                        Canvas {
                            id:      extractCanvas
                            width:   coverSz; height: coverSz
                            visible: false
                            property var grabResult: null

                            onPaint: {
                                if (!grabResult) return
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, 100, 100)
                                ctx.drawImage(grabResult.url, 0, 0, 100, 100)
                                var raw = ctx.getImageData(0, 0, 100, 100).data
                                if (coverMain.imgPixels === null) {
                                    // First cover: direct display without transition
                                    coverMain.imgPixels = raw
                                    coverMain.requestPaint()
                                } else {
                                    // Cover change: blocky transition
                                    coverMain.nextImgPixels = raw
                                    blockTimer.step = 0
                                    blockTimer.running = true
                                }
                                coverArea.hoverIntensity = new Array(32*32).fill(0)
                                coverArea.hoverR = new Array(32*32).fill(200)
                                coverArea.hoverG = new Array(32*32).fill(184)
                                coverArea.hoverB = new Array(32*32).fill(154)
                                coverHover.requestPaint()
                            }
                        }

                        Connections {
                            target: root
                            function onMpCoverUrlChanged() {
                                if (root.mpCoverUrl !== "") {
                                    coverSrc.source = ""
                                    coverSrc.source = root.mpCoverUrl
                                } else {
                                    coverMain.imgPixels = null
                                    coverMain.requestPaint()
                                }
                            }
                        }

                        // Hover color brush canvas
                        Canvas {
                            id:     coverHover
                            width:  coverSz; height: coverSz
                            smooth: false
                            z:      2

                            onPaint: {
                                var ctx  = getContext("2d")
                                var GRID = 32, CELL = 100/GRID
                                var ci = coverArea.hoverIntensity
                                var cr = coverArea.hoverR
                                var cg = coverArea.hoverG
                                var cb = coverArea.hoverB
                                ctx.clearRect(0, 0, 100, 100)
                                for (var r = 0; r < GRID; r++) for (var c = 0; c < GRID; c++) {
                                    var i = r*GRID + c
                                    if (ci[i] > 0.01) {
                                        ctx.fillStyle = "rgba(" + cr[i] + "," + cg[i] + "," + cb[i] + "," + ci[i] + ")"
                                        ctx.fillRect(c*CELL, r*CELL, Math.ceil(CELL)+1, Math.ceil(CELL)+1)
                                    }
                                }
                            }
                        }

                        Timer {
                            id: decayTimer; interval: 16; repeat: true; running: false
                            onTriggered: {
                                var ci = coverArea.hoverIntensity.slice()
                                var active = false
                                for (var i = 0; i < 32*32; i++) {
                                    if (ci[i] > 0) { ci[i] = Math.max(0, ci[i] - 0.014); active = true }
                                }
                                coverArea.hoverIntensity = ci
                                coverHover.requestPaint()
                                if (!active) decayTimer.running = false
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.CrossCursor
                            onPositionChanged: {
                                var GRID = 32, CELL = 100/GRID, BRUSH_R = 2
                                var cc = Math.floor(mouseX / CELL)
                                var cr = Math.floor(mouseY / CELL)
                                var ci = coverArea.hoverIntensity.slice()
                                var cr2 = coverArea.hoverR.slice()
                                var cg  = coverArea.hoverG.slice()
                                var cb  = coverArea.hoverB.slice()
                                var src = coverMain.imgPixels
                                for (var dr = -BRUSH_R; dr <= BRUSH_R; dr++) {
                                    for (var dc = -BRUSH_R; dc <= BRUSH_R; dc++) {
                                        var nc = cc+dc, nr = cr+dr
                                        if (nc<0||nc>=GRID||nr<0||nr>=GRID) continue
                                        var dist = Math.sqrt(dc*dc + dr*dr)
                                        var alpha = Math.max(0, 1 - dist/(BRUSH_R+0.5))
                                        var strength = alpha*alpha
                                        if (strength < 0.01) continue
                                        if (src) {
                                            var sx  = Math.min(Math.floor(nc*CELL + CELL/2), 99)
                                            var sy  = Math.min(Math.floor(nr*CELL + CELL/2), 99)
                                            var idx = (sy*100 + sx)*4
                                            if (strength > ci[nr*GRID+nc]*0.6) {
                                                cr2[nr*GRID+nc] = src[idx]
                                                cg[nr*GRID+nc]  = src[idx+1]
                                                cb[nr*GRID+nc]  = src[idx+2]
                                            }
                                        }
                                        ci[nr*GRID+nc] = Math.min(1, ci[nr*GRID+nc] + strength*0.9)
                                    }
                                }
                                coverArea.hoverIntensity = ci
                                coverArea.hoverR = cr2; coverArea.hoverG = cg; coverArea.hoverB = cb
                                coverHover.requestPaint()
                                decayTimer.running = true
                            }
                            onExited: decayTimer.running = true
                        }

                        // Scanlines on the cover
                        Item {
                            anchors.fill: parent; z: 3
                            Repeater {
                                model: 33
                                Rectangle {
                                    y:     index*3 + 2
                                    width: 100; height: 1
                                    color: Qt.rgba(0, 0, 0, 0.14)
                                }
                            }
                        }

                        // Right border
                        Rectangle {
                            anchors.right: parent.right; z: 4
                            width: 1; height: parent.height
                            color: Qt.rgba(200/255,184/255,154/255,0.1)
                        }
                    }

                    // Info column
                    Item {
                        x: coverSz; width: pw - coverSz; height: coverSz

                        Column {
                            anchors { fill: parent; topMargin: 7; leftMargin: 9; rightMargin: 9 }
                            spacing: 0

                            // Title
                            // Title — scrolls like the ticker (0.5x speed) if it overflows
                            // Title — reveals overflow by scrolling left from resting position
                            Item {
                                id:     ciTitleClip
                                width:  parent.width
                                height: ciTitle.implicitHeight
                                clip:   true

                                Text {
                                    id:   ciTitle
                                    text: root.mpTitle
                                    font.family: "Share Tech Mono"
                                    font.pixelSize: s(12)
                                    font.letterSpacing: 1.5
                                    color: Qt.rgba(200/255,184/255,154/255,0.9)

                                    // Slide-in animation when the title changes
                                    Behavior on text {
                                        SequentialAnimation {
                                            PropertyAnimation { target: ciTitle; property: "opacity"; to: 0; duration: 80 }
                                            PropertyAnimation { target: ciTitle; property: "x"; to: -10; duration: 0 }
                                            PropertyAnimation { target: ciTitle; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                            PropertyAnimation { target: ciTitle; property: "opacity"; to: 1; duration: 180 }
                                        }
                                    }

                                    // Marquee reveal — starts at resting position (x=0),
                                    // scrolls left to reveal the overflow, pauses, resets
                                    SequentialAnimation on x {
                                        running: ciTitle.implicitWidth > ciTitleClip.width && root.shown
                                        loops:   Animation.Infinite

                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            from: 0
                                            to:   -(ciTitle.implicitWidth - ciTitleClip.width)
                                            duration: Math.max(1, (ciTitle.implicitWidth - ciTitleClip.width)) / (root.tickerSpeed * 0.5)
                                            easing.type: Easing.Linear
                                        }
                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            to: 0
                                            duration: Math.max(1, (ciTitle.implicitWidth - ciTitleClip.width)) / (root.tickerSpeed * 0.5)
                                            easing.type: Easing.Linear
                                        }
                                    }
                                }
                            }

                            Item { width: 1; height: 2 }

                            // Artist
                            // Artist — scrolls like the ticker (0.5x speed) if it overflows
                            // Artist — reveals overflow by scrolling left from resting position
                            Item {
                                id:     ciArtistClip
                                width:  parent.width
                                height: ciArtist.implicitHeight
                                clip:   true

                                Text {
                                    id:   ciArtist
                                    text: root.mpArtist
                                    font.family: "Share Tech Mono"
                                    font.pixelSize: s(10)
                                    font.letterSpacing: 1
                                    color: Qt.rgba(200/255,184/255,154/255,0.42)

                                    SequentialAnimation on x {
                                        running: ciArtist.implicitWidth > ciArtistClip.width && root.shown
                                        loops:   Animation.Infinite

                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            from: 0
                                            to:   -(ciArtist.implicitWidth - ciArtistClip.width)
                                            duration: Math.max(1, (ciArtist.implicitWidth - ciArtistClip.width)) / (root.tickerSpeed * 0.5)
                                            easing.type: Easing.Linear
                                        }
                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            to: 0
                                            duration: Math.max(1, (ciArtist.implicitWidth - ciArtistClip.width)) / (root.tickerSpeed * 0.5)
                                            easing.type: Easing.Linear
                                        }
                                    }
                                }
                            }
                            
                            Item { width: 1; height: 4 }

                            // Tags
                            Row {
                                spacing: 3
                                Repeater {
                                    model: ["LOSSLESS","48k","FLAC"]
                                    Rectangle {
                                        implicitWidth: tagTxt.implicitWidth + 8
                                        height: 13; color: "transparent"
                                        border.width: 1
                                        border.color: index < 2
                                            ? Qt.rgba(200/255,184/255,154/255,0.3)
                                            : Qt.rgba(200/255,184/255,154/255,0.14)
                                        Text {
                                            id: tagTxt
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(9)
                                            font.letterSpacing: 1
                                            color: index < 2
                                                ? Qt.rgba(200/255,184/255,154/255,0.6)
                                                : Qt.rgba(200/255,184/255,154/255,0.3)
                                        }
                                    }
                                }
                            }

                            Item { width: 1; height: 1 }

                            // Controls
                            Row {
                                spacing: 4; topPadding: 5

                                // PREV
                                CBtn {
                                    id: prevBtn
                                    svgIcon: true
                                    onClicked: root.prevTrack()
                                    Text {
                                        anchors.centerIn: parent
                                        text: "◀"; font.pixelSize: s(11)
                                        color: prevBtn.textColor
                                        z: 1
                                    }
                                }

                                // PLAY / PAUSE
                                CBtn {
                                    id: playBtn
                                    isPlay: true
                                    onClicked: root.playPause()
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.mpPlaying ? "PAUSE" : "PLAY"
                                        font.family: "Share Tech Mono"
                                        font.pixelSize: s(9)
                                        font.letterSpacing: 1
                                        color: playBtn.textColor
                                        z: 1
                                    }
                                }

                                // NEXT
                                CBtn {
                                    id: nextBtn
                                    svgIcon: true
                                    onClicked: root.nextTrack()
                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"; font.pixelSize: s(11)
                                        color: nextBtn.textColor
                                        z: 1
                                    }
                                }
                            }
                        }
                    }
                }

                // ── PROGRESS ──
                Column {
                    width: pw

                    // Time
                    Item {
                        width: pw;  height: s(16)
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 0 }
                            text: root.fmtTime(root.mpPosition)
                            font.family: "Share Tech Mono"; font.pixelSize: s(7); font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.2)
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 0 }
                            text: root.fmtTime(root.mpLength)
                            font.family: "Share Tech Mono"; font.pixelSize: s(7); font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.2)
                        }
                    }

                    // Progress bar
                    Item {
                        id:     seekBar
                        width:  pw;  height: s(14)

                        // Background
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 2
                            color: Qt.rgba(200/255,184/255,154/255,0.08)
                        }
                        // Fill
                        Rectangle {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left }
                            height: 2
                            color:  Qt.rgba(200/255,184/255,154/255,0.6)
                            width:  root.mpLength > 0
                                    ? seekBar.width * root.mpPosition / root.mpLength
                                    : 0
                        }
                        // Head
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x:     root.mpLength > 0
                                   ? seekBar.width * root.mpPosition / root.mpLength - 0.5
                                   : 0
                            width: 1; height: 8
                            color: Qt.rgba(200/255,184/255,154/255,0.8)
                        }

                        MouseArea {
                            anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
                            property bool dragging: false
                            onPressed:  { dragging = true;  doSeek(mouseX) }
                            onReleased: { dragging = false }
                            onPositionChanged: if (dragging) doSeek(mouseX)
                            function doSeek(mx) {
                                var pct  = Math.max(0, Math.min(1, mx / seekBar.width))
                                seekProc.seekSecs = pct * root.mpLength
                                seekProc.running  = true
                            }
                        }
                    }

                    Item { width: 1; height: 2 }
                }

                // ── STATUS BAR ──
                Item {
                    width: pw;  height: s(18)

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.05)
                    }

                    Row {
                        anchors { fill: parent; leftMargin: 0; rightMargin: 0 }

                        Item { width: 8; height: 1 }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Rectangle {
                                width: 4; height: 4
                                color: root.mpPlaying
                                    ? Qt.rgba(88/255,158/255,110/255,0.55)
                                    : Qt.rgba(200/255,184/255,154/255,0.15)
                                SequentialAnimation on opacity {
                                    running: root.mpPlaying && root.shown; loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 700 }
                                    NumberAnimation { to: 1; duration: 700 }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.mpPlaying ? "STREAMING" : "IDLE"
                                font.family: "Share Tech Mono"; font.pixelSize: s(6); font.letterSpacing: 1
                                color: Qt.rgba(200/255,184/255,154/255,0.15)
                            }
                        }

                        Item { width: parent.width - 180; height: 1 }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.clockStr
                            font.family: "Share Tech Mono"; font.pixelSize: s(6); font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.15)
                        }

                        Item { width: 8; height: 1 }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LOSSLESS 48k"
                            font.family: "Share Tech Mono"; font.pixelSize: s(6); font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.15)
                        }
                    }
                }
            }

            // CornerDeco on top of all content
            CornerDeco {
                width:  pw
                height: playerCol.implicitHeight
                lineColor: Qt.rgba(200/255,184/255,154/255,0.3)
                size: 18
                z:    5
            }
        }

        // ── CURTAIN — sibling of the content inside the clipped wipeHost ──
        Rectangle {
            id:    curtain
            anchors { top: parent.top; bottom: parent.bottom }
            color: "#c8b89a"
            z:     10

            // Initial state: hidden (width=2, on the right)
            width: 2
            x:     318
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // TOGGLE: slide in from off-screen (right → inside)
    // The player slides along its X axis — the PanelWindow keeps its size
    // The wipe curtain animates AT THE SAME TIME as the slide
    // ─────────────────────────────────────────────────────────────────

    // Custom curve: slow at the start, aggressive toward the end
    // Reproduces a cubic-bezier(.4,0,.2,1) but with a final snap
    NumberAnimation {
        id:       slideInAnim
        target:   wipeHost
        property: "x"
        from:     340; to: 0
        duration: 480
        // InOutQuart = accelerates + brakes — we want OutExpo (slow then snap)
        easing.type:     Easing.OutExpo
    }

    NumberAnimation {
        id:       slideOutAnim
        target:   wipeHost
        property: "x"
        from:     0; to: 340
        duration: 380
        easing.type: Easing.InExpo
        onFinished: {
            wipeHost.visible = false
            curtain.x = 318; curtain.width = 2
        }
    }

    // ── REVEAL ──
    // The player slides in from the right, opaque from the start.
    // The sepia bar is the left edge of the player — it moves with it.
    // Reading: wipeHost.x goes from 320 → 0. The curtain sits at x=0 inside wipeHost,
    // so it's always on the left edge of the visible player.
    // Once in place, the curtain retracts (revealing the content).
    SequentialAnimation {
        id: revealAnim

        // Phase 1: player + curtain (2px strip) enter together from the right
        // The curtain is glued to the left edge of the player (x=0 inside wipeHost)
        // We animate wipeHost.x: the whole thing slides in from off-screen
        ParallelAnimation {
            NumberAnimation {
                target: wipeHost; property: "x"
                from: pw+2; to: 0
                duration: 460
                easing.type: Easing.OutExpo
            }
            // Content is hidden during the entry phase
            // (the full-width curtain covers it)
            NumberAnimation {
                target: curtain; property: "width"
                from: 320; to: 320
                duration: 460
            }
        }

        // Phase 2: player is in place — curtain retracts to the left
        // Reveals the content with an expo snap
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: 0
                duration: 340
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: 320; to: 0
                duration: 340
                easing.type: Easing.OutExpo
            }
        }

        onStarted: {
            wipeHost.x = pw+2
            wipeHost.opacity = 1
            wipeHost.visible = true
            curtain.x        = 0
            curtain.width = pw
        }
        onFinished: {
            wipeHost.x    = 0
            curtain.x     = 0
            curtain.width = 0
            titleSlideIn.start()
            artistFadeIn.start()
        }
    }

    // ── HIDE ──
    // Curtain covers the content, then the whole thing slides out to the right at once
    SequentialAnimation {
        id: hideAnim

        // Phase 1: curtain covers the content (expands left to right)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: 0
                duration: 180
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: 0; to: 320
                duration: 180
                easing.type: Easing.InOutQuart
            }
        }

        // Phase 2: everything slides off-screen to the right with an expo snap
        NumberAnimation {
            target: wipeHost; property: "x"
            from: 0; to: pw+2
            duration: 380
            easing.type: Easing.InExpo
        }

        onStarted: {
            curtain.x     = 0
            curtain.width = 0
        }
        onFinished: {
            wipeHost.visible = false
            wipeHost.x = pw+2
            curtain.x        = 0
            curtain.width = pw
        }
    }

    // Text animations when the player enters
    SequentialAnimation {
        id: titleSlideIn
        PropertyAction  { target: ciTitle;  property: "x";       value: -12 }
        PropertyAction  { target: ciTitle;  property: "opacity";  value: 0  }
        PropertyAction  { target: ciArtist; property: "opacity";  value: 0  }
        PauseAnimation  { duration: 80 }
        ParallelAnimation {
            NumberAnimation { target: ciTitle;  property: "x";      from: -12; to: 0; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: ciTitle;  property: "opacity"; from: 0;  to: 1; duration: 200 }
        }
    }
    NumberAnimation {
        id: artistFadeIn
        target: ciArtist; property: "opacity"
        from: 0; to: 1
        duration: 280
        easing.type: Easing.OutQuad
    }

    // ── SEEK PROCESS ──
    Process {
        id: seekProc
        property real seekSecs: 0
        command: ["playerctl", "position", String(Math.round(seekSecs))]
        running: false
    }

    // ── CLOCK ──
    Timer {
        interval: 1000; running: root.shown; repeat: true
        onTriggered: {
            var d = new Date()
            root.clockStr = String(d.getHours()).padStart(2,"0") + ":"
                          + String(d.getMinutes()).padStart(2,"0")
        }
    }

    // ── PUBLIC API ──
    function toggleVisible() {
        if (root.shown) {
            root.shown = false
            revealAnim.stop()
            hideAnim.start()
        } else {
            root.shown = true
            var d = new Date()
            root.clockStr = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
            hideAnim.stop()
            revealAnim.start()
        }
    }

    // ── Expose toggle via Quickshell IPC ──
    // Callable from CLI with:   qs ipc call player toggle
    IpcHandler {
        target: "player"
        function toggle(): void { root.toggleVisible() }
        function show(): void   { if (!root.shown) root.toggleVisible() }
        function hide(): void   { if ( root.shown) root.toggleVisible() }
    }

    function fmtTime(secs) {
        var s = Math.max(0, Math.floor(secs))
        return Math.floor(s/60) + ":" + String(s%60).padStart(2,"0")
    }

    Component.onCompleted: {
        var d = new Date()
        clockStr = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
    }

    // ── CONTROL BUTTON COMPONENT (fill-slide) ──
    component CBtn: Item {
        id:            btnRoot
        property bool svgIcon: false
        property bool isPlay:  false
        signal clicked

        width:  isPlay ? 44 : 22
        height: 22

        Rectangle {
            anchors.fill: parent; color: "transparent"
            border.width: 1
            border.color: parent.isPlay
                ? Qt.rgba(200/255,184/255,154/255,0.3)
                : Qt.rgba(200/255,184/255,154/255,0.1)

            // Fill slide left→right
            Rectangle {
                id:    cbFill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 0; z: 0
                color: Qt.rgba(200/255,184/255,154/255,0.8)
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuart } }
            }
        }

        // Text or icon (set via children)
        // The color changes via MouseArea hover
        property color textColor: cbMa.containsMouse
            ? "#0b0a09"
            : (isPlay
                ? Qt.rgba(200/255,184/255,154/255,0.85)
                : Qt.rgba(200/255,184/255,154/255,0.38))

        MouseArea {
            id:           cbMa
            anchors.fill: parent
            hoverEnabled: true
            onEntered:    cbFill.width = btnRoot.width
            onExited:     cbFill.width = 0
            onClicked:    btnRoot.clicked()
            onPressed:    btnRoot.scale = 0.95
            onReleased:   btnRoot.scale = 1.0
        }
    }
}