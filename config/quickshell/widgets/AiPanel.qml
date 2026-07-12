import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../settings"

// ═════════════════════════════════════════════════════════════════════
//   NieR AI Chat Panel — Quickshell widget
//   Slides in from the LEFT edge (mirror of Player.qml's right-side entry)
//   Uses the same animation language: curtain wipe + expo slide
//   IPC : qs ipc call ai toggle
// ═════════════════════════════════════════════════════════════════════

Item {
    id: root

    // ── Shorthand Settings ──
    readonly property real sc: Settings.scale
    function s(px) { return Math.round(px * sc) }

    // ── Sizing — 20% screen width, 80% screen height ──
    property real screenW: 1920
    property real screenH: 1080
    readonly property int pw: Math.round(screenW * 0.20)
    readonly property int ph: Math.round(screenH * 0.80)

    // ── State ──
    property bool   shown: false
    property string clockStr: "--:--"
    property bool   pinned: false
    readonly property bool animRunning: hideAnim.running || revealAnim.running
    readonly property int panelRestX: Settings.aiPanelMarginLeft  // x when panel is fully visible

    // Exposed dimensions and hover state for PanelWindow mask & focus
    readonly property int panelX: wipeHost.x
    readonly property int panelY: wipeHost.y
    readonly property int panelWidth: wipeHost.width
    readonly property int panelHeight: wipeHost.height
    readonly property bool hovered: panelHoverHandler.hovered

    // ── Chat state ──
    property var    messages: []      // [{role:"user"|"assistant"|"error", content:"..."}]
    property bool   loading:  false
    property string inputText: ""

    // ── Click-outside-to-close overlay (same pattern as Menu.qml) ──
    // Full-screen transparent MouseArea behind the panel; clicking it
    // dismisses AiPanel via the same toggleVisible() path as IPC.
    MouseArea {
        anchors.fill: parent
        enabled: root.shown && !root.pinned
        visible: root.shown || root.animRunning
        onClicked: root.toggleVisible()
    }

    // ──────────────────────────────────────────────────────────────
    // WIPE HOST — clipped Item containing curtain + content
    // Mirror of Player.qml but slides from LEFT (negative x)
    // ──────────────────────────────────────────────────────────────
    Item {
        id:      wipeHost
        width:   pw
        height:  ph
        clip:    true
        y:       Math.round(root.screenH * Settings.aiPanelPositionY)
        x:       -(pw + 2)       // starts off-screen to the LEFT (hidden)
        opacity: 1
        visible: false

        HoverHandler {
            id: panelHoverHandler
        }

        // ── CONTENT ──
        Item {
            id:      content
            width:   pw
            height:  ph

            // Background
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(11/255, 10/255, 9/255, 0.94)
            }

            Column {
                id:     mainCol
                width:  pw
                height: ph

                // ── TOP TICKER BAR ──
                Item {
                    width: pw; height: s(14); clip: true
                    Text {
                        id:   aiTicker
                        text: "YoRHa // TACTICAL AI INTERFACE // MODEL: "
                              + Settings.aiModel.toUpperCase()
                              + " // PROVIDER: " + Settings.aiProvider.toUpperCase()
                              + " // READY //\u00a0"
                        font.family: "Share Tech Mono"
                        font.pixelSize: s(8)
                        font.letterSpacing: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.2)
                        y: 3
                        NumberAnimation on x {
                            from: root.pw; to: -aiTicker.implicitWidth
                            duration: 22000; loops: Animation.Infinite; running: true
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.06)
                    }
                }

                // ── TOP BORDER ──
                Rectangle {
                    width: pw; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: Qt.rgba(200/255,184/255,154/255,0.5) }
                        GradientStop { position: 0.8; color: Qt.rgba(200/255,184/255,154/255,0.5) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // ── HEADER ──
                Item {
                    width: pw; height: s(28)
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: s(10) }
                        text: "TACTICAL LOG"
                        font.family: "Share Tech Mono"
                        font.pixelSize: s(11)
                        font.letterSpacing: 2
                        color: Qt.rgba(200/255,184/255,154/255,0.85)
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: s(10) }
                        spacing: s(8)

                        // Pin button
                        Item {
                            id: pinBtn
                            width: s(28)
                            height: s(14)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                color: root.pinned 
                                    ? Qt.rgba(200/255, 184/255, 154/255, 0.12)
                                    : (pinMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.04) : "transparent")
                                border.width: 1
                                border.color: root.pinned || pinMa.containsMouse
                                    ? Qt.rgba(200/255, 184/255, 154/255, 0.4)
                                    : Qt.rgba(200/255, 184/255, 154/255, 0.12)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "PIN"
                                font.family: "Share Tech Mono"
                                font.pixelSize: s(7)
                                font.letterSpacing: 1
                                color: root.pinned
                                    ? Qt.rgba(200/255, 184/255, 154/255, 0.85)
                                    : (pinMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.6) : Qt.rgba(200/255, 184/255, 154/255, 0.25))

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: pinMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.pinned = !root.pinned
                            }
                        }

                        Text {
                            text: root.clockStr
                            font.family: "Share Tech Mono"
                            font.pixelSize: s(7)
                            font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.25)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.08)
                    }
                }

                // ── MESSAGES AREA ──
                Item {
                    id: messagesArea
                    width: pw
                    height: ph - s(14) - 1 - s(28) - s(18) - inputRow.height - 1
                    clip: true

                    Flickable {
                        id: messageFlick
                        anchors.fill: parent
                        anchors.margins: s(6)
                        contentHeight: msgCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: msgCol
                            width: messageFlick.width
                            spacing: s(6)

                            // Welcome message when empty
                            Item {
                                width: parent.width
                                height: welcomeCol.implicitHeight + s(12)
                                visible: root.messages.length === 0

                                Column {
                                    id: welcomeCol
                                    anchors.centerIn: parent
                                    width: parent.width - s(16)
                                    spacing: s(6)

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "[ SYSTEM ONLINE ]"
                                        font.family: "Share Tech Mono"
                                        font.pixelSize: s(10)
                                        font.letterSpacing: 2
                                        color: Qt.rgba(200/255,184/255,154/255,0.4)
                                    }
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: "YoRHa Tactical AI ready.\nAwaiting operator input."
                                        font.family: "Share Tech Mono"
                                        font.pixelSize: s(8)
                                        font.letterSpacing: 1
                                        color: Qt.rgba(200/255,184/255,154/255,0.2)
                                        lineHeight: 1.4
                                    }
                                }
                            }

                            // Message bubbles
                            Repeater {
                                model: root.messages.length
                                delegate: Item {
                                    id: msgDelegate
                                    required property int index
                                    width: msgCol.width
                                    height: msgBubble.implicitHeight + s(6)

                                     property var msg: root.messages[index]
                                     property bool isUser: msg.role === "user"
                                     property bool isError: msg.role === "error"

                                     readonly property int bubblePaddingH: isUser ? s(9) : s(11)
                                     readonly property int bubblePaddingB: isUser ? s(8) : s(10)
                                     readonly property int labelTopMargin: s(4)
                                     readonly property int textTopMargin: s(3)

                                    Rectangle {
                                        id: msgBubble
                                        width: Math.min(msgText.implicitWidth + (msgDelegate.bubblePaddingH * 2), parent.width * 0.88)
                                        implicitHeight: msgDelegate.labelTopMargin + roleLabel.implicitHeight + msgDelegate.textTopMargin + msgText.implicitHeight + msgDelegate.bubblePaddingB
                                        anchors.right: msgDelegate.isUser ? parent.right : undefined
                                        anchors.left:  msgDelegate.isUser ? undefined : parent.left
                                        color: msgDelegate.isError
                                            ? Qt.rgba(200/255, 112/255, 96/255, 0.1)
                                            : msgDelegate.isUser
                                                ? Qt.rgba(200/255,184/255,154/255,0.08)
                                                : Qt.rgba(96/255,168/255,128/255,0.06)
                                        border.width: 1
                                        border.color: msgDelegate.isError
                                            ? Qt.rgba(200/255, 112/255, 96/255, 0.3)
                                            : msgDelegate.isUser
                                                ? Qt.rgba(200/255,184/255,154/255,0.15)
                                                : Qt.rgba(96/255,168/255,128/255,0.15)

                                        // Role label
                                        Text {
                                            id: roleLabel
                                            anchors {
                                                top: parent.top
                                                left: parent.left
                                                topMargin: msgDelegate.labelTopMargin
                                                leftMargin: msgDelegate.bubblePaddingH
                                            }
                                            text: msgDelegate.isError ? "ERR" : (msgDelegate.isUser ? "OPERATOR" : "AI")
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(6)
                                            font.letterSpacing: 1.5
                                            color: msgDelegate.isError
                                                ? Qt.rgba(200/255, 112/255, 96/255, 0.6)
                                                : msgDelegate.isUser
                                                    ? Qt.rgba(200/255,184/255,154/255,0.35)
                                                    : Qt.rgba(96/255,168/255,128/255,0.45)
                                        }

                                        Text {
                                            id: msgText
                                            anchors {
                                                top: roleLabel.bottom
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: msgDelegate.bubblePaddingH
                                                rightMargin: msgDelegate.bubblePaddingH
                                                topMargin: msgDelegate.textTopMargin
                                            }
                                            text: msgDelegate.msg.content
                                            textFormat: msgDelegate.isUser || msgDelegate.isError
                                                ? Text.PlainText
                                                : Text.MarkdownText
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(Settings.aiChatFontSize)
                                            font.letterSpacing: 0.5
                                            color: msgDelegate.isError
                                                ? Qt.rgba(200/255, 112/255, 96/255, 0.8)
                                                : Qt.rgba(200/255,184/255,154/255,0.75)
                                            linkColor: Qt.rgba(200/255,184/255,154/255,0.9)
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.3
                                        }
                                    }
                                }
                            }

                            // Loading indicator
                            Item {
                                width: msgCol.width
                                height: s(24)
                                visible: root.loading

                                Row {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    spacing: s(4)

                                    Rectangle {
                                        width: s(4); height: s(4)
                                        color: Qt.rgba(96/255,168/255,128/255,0.5)
                                        SequentialAnimation on opacity {
                                            running: root.loading; loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 400 }
                                            NumberAnimation { to: 1.0; duration: 400 }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "PROCESSING..."
                                        font.family: "Share Tech Mono"
                                        font.pixelSize: s(7)
                                        font.letterSpacing: 1
                                        color: Qt.rgba(96/255,168/255,128/255,0.4)
                                        SequentialAnimation on opacity {
                                            running: root.loading; loops: Animation.Infinite
                                            NumberAnimation { to: 0.4; duration: 600 }
                                            NumberAnimation { to: 1.0; duration: 600 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Left accent line
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.06)
                    }
                }

                // ── INPUT DIVIDER ──
                Rectangle {
                    width: pw; height: 1
                    color: Qt.rgba(200/255,184/255,154/255,0.1)
                }

                // ── INPUT ROW ──
                Item {
                    id: inputRow
                    width: pw
                    height: Math.max(s(36), 32)

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(200/255,184/255,154/255,0.02)
                    }

                    // Input field background
                    Rectangle {
                        id: inputBg
                        anchors {
                            left: parent.left; right: sendBtn.left
                            top: parent.top; bottom: parent.bottom
                            margins: s(5)
                            rightMargin: s(3)
                        }
                        color: Qt.rgba(200/255,184/255,154/255,0.04)
                        border.width: 1
                        border.color: inputField.activeFocus
                            ? Qt.rgba(200/255,184/255,154/255,0.25)
                            : Qt.rgba(200/255,184/255,154/255,0.08)

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        TextInput {
                            id: inputField
                            anchors {
                                fill: parent
                                leftMargin: s(6); rightMargin: s(6)
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Share Tech Mono"
                            font.pixelSize: s(Settings.aiChatFontSize)
                            font.letterSpacing: 0.5
                            color: Qt.rgba(200/255,184/255,154/255,0.8)
                            selectionColor: Qt.rgba(200/255,184/255,154/255,0.25)
                            selectedTextColor: Qt.rgba(200/255,184/255,154/255,1.0)
                            clip: true

                            onAccepted: root.sendMessage()

                            // Placeholder
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Enter query..."
                                font: inputField.font
                                color: Qt.rgba(200/255,184/255,154/255,0.2)
                                visible: !inputField.text && !inputField.activeFocus
                            }
                        }
                    }

                    // Send button
                    Item {
                        id: sendBtn
                        anchors {
                            right: parent.right; top: parent.top; bottom: parent.bottom
                            margins: s(5)
                        }
                        width: s(36)

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(200/255,184/255,154/255,0.12)

                            Rectangle {
                                id: sendFill
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 0; z: 0
                                color: Qt.rgba(200/255,184/255,154/255,0.8)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuart } }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            font.pixelSize: s(11)
                            color: sendMa.containsMouse ? "#0b0a09" : Qt.rgba(200/255,184/255,154/255,0.5)
                            z: 1

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            id: sendMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered:  sendFill.width = sendBtn.width
                            onExited:   sendFill.width = 0
                            onClicked:  root.sendMessage()
                            onPressed:  sendBtn.scale = 0.95
                            onReleased: sendBtn.scale = 1.0
                        }
                    }
                }

                // ── STATUS BAR ──
                Item {
                    width: pw; height: s(18)

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 1
                        color: Qt.rgba(200/255,184/255,154/255,0.05)
                    }

                    Row {
                        anchors { fill: parent; leftMargin: s(8); rightMargin: s(8) }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Rectangle {
                                width: 4; height: 4
                                color: root.loading
                                    ? Qt.rgba(200/255, 168/255, 96/255, 0.55)
                                    : Qt.rgba(88/255, 158/255, 110/255, 0.55)
                                SequentialAnimation on opacity {
                                    running: root.loading; loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.loading ? "TRANSMITTING" : "STANDBY"
                                font.family: "Share Tech Mono"; font.pixelSize: s(6); font.letterSpacing: 1
                                color: Qt.rgba(200/255,184/255,154/255,0.15)
                            }
                        }

                        Item { width: parent.width - s(200); height: 1 }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Settings.aiProvider.toUpperCase() + " // " + Settings.aiModel.toUpperCase()
                            font.family: "Share Tech Mono"; font.pixelSize: s(6); font.letterSpacing: 1
                            color: Qt.rgba(200/255,184/255,154/255,0.15)
                            elide: Text.ElideRight
                            width: s(160)
                        }
                    }
                }
            }

            // CornerDeco overlay
            CornerDeco {
                width:  pw
                height: ph
                lineColor: Qt.rgba(200/255,184/255,154/255,0.3)
                size: 18
                z: 5
            }

            // Scanlines overlay
            Scanlines {
                anchors.fill: parent
                lineOpacity: 0.04
                grain: true
                z: 4
            }
        }

        // ── CURTAIN — sepia wipe rectangle (sibling of content inside wipeHost) ──
        Rectangle {
            id:    curtain
            anchors { top: parent.top; bottom: parent.bottom }
            color: Settings.curtainColor
            z:     10

            // Initial: hidden (2px strip on the left)
            width: 2
            x:     0
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // ANIMATION — Mirror of Player.qml but from the LEFT
    // Player slides right→center, AiPanel slides left→center
    // ─────────────────────────────────────────────────────────────────

    // ── REVEAL ──
    // Panel + curtain enter from the left, then curtain retracts right→left
    SequentialAnimation {
        id: revealAnim

        // Phase 1: panel + curtain (full width) enter together from the left
        ParallelAnimation {
            NumberAnimation {
                target: wipeHost; property: "x"
                from: -(pw + 2); to: panelRestX
                duration: Settings.revealDuration
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: pw; to: pw
                duration: Settings.revealDuration
            }
        }

        // Phase 2: panel in place — curtain retracts to the RIGHT (reveals content)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: pw
                duration: 340
                easing.type: Easing.OutExpo
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: pw; to: 0
                duration: 340
                easing.type: Easing.OutExpo
            }
        }

        onStarted: {
            wipeHost.x       = -(pw + 2)
            wipeHost.opacity = 1
            wipeHost.visible = true
            curtain.x        = 0
            curtain.width    = pw
        }
        onFinished: {
            wipeHost.x    = panelRestX
            curtain.x     = pw
            curtain.width = 0
            inputField.forceActiveFocus()
        }
    }

    // ── HIDE ──
    // Curtain covers content (right→left), then panel slides off-screen left
    SequentialAnimation {
        id: hideAnim

        // Phase 1: curtain covers from the RIGHT
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: pw; to: 0
                duration: 180
                easing.type: Easing.InOutQuart
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: 0; to: pw
                duration: 180
                easing.type: Easing.InOutQuart
            }
        }

        // Phase 2: everything slides off-screen to the LEFT
        NumberAnimation {
            target: wipeHost; property: "x"
            from: panelRestX; to: -(pw + 2)
            duration: Settings.hideDuration
            easing.type: Easing.InExpo
        }

        onStarted: {
            curtain.x     = pw
            curtain.width = 0
        }
        onFinished: {
            wipeHost.visible = false
            wipeHost.x       = -(pw + 2)
            curtain.x        = 0
            curtain.width    = pw
        }
    }

    // ── CLOCK ──
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            var d = new Date()
            root.clockStr = String(d.getHours()).padStart(2,"0") + ":"
                          + String(d.getMinutes()).padStart(2,"0")
        }
    }

    // ──────────────────────────────────────────────────────────────
    // PUBLIC API
    // ──────────────────────────────────────────────────────────────
    function toggleVisible() {
        if (root.shown) {
            root.shown = false
            revealAnim.stop()
            hideAnim.start()
        } else {
            root.shown = true
            hideAnim.stop()
            revealAnim.start()
        }
    }

    // ── IPC — callable with: qs ipc call ai toggle ──
    IpcHandler {
        target: "ai"
        function toggle(): void { root.toggleVisible() }
        function show(): void   { if (!root.shown) root.toggleVisible() }
        function hide(): void   { if ( root.shown) root.toggleVisible() }
    }

    // ──────────────────────────────────────────────────────────────
    // CHAT LOGIC
    // ──────────────────────────────────────────────────────────────

    function sendMessage() {
        var text = inputField.text.trim()
        if (text === "" || root.loading) return

        // Add user message
        var msgs = root.messages.slice()
        msgs.push({role: "user", content: text})
        root.messages = msgs
        inputField.text = ""
        root.loading = true

        // Scroll to bottom
        scrollToBottom()

        // Dispatch to provider
        var provider = Settings.aiProvider
        if      (provider === "ollama")      sendOllama(text)
        else if (provider === "groq")        sendGroq(text)
        else if (provider === "openrouter")  sendOpenRouter(text)
        else if (provider === "gemini")      sendGemini(text)
        else    appendError("Unknown provider: " + provider)
    }

    function scrollToBottom() {
        Qt.callLater(function() {
            messageFlick.contentY = Math.max(0, msgCol.implicitHeight - messageFlick.height)
        })
    }

    function appendAssistant(text) {
        var msgs = root.messages.slice()
        msgs.push({role: "assistant", content: text})
        root.messages = msgs
        root.loading = false
        scrollToBottom()
    }

    function appendError(text) {
        var msgs = root.messages.slice()
        msgs.push({role: "error", content: text})
        root.messages = msgs
        root.loading = false
        scrollToBottom()
    }

    // ── Build message history for chat-completion APIs ──
    // Prepends the system prompt from Settings if non-empty
    function buildChatHistory() {
        var history = []
        if (Settings.aiSystemPrompt)
            history.push({role: "system", content: Settings.aiSystemPrompt})
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            if (m.role === "user" || m.role === "assistant") {
                history.push({role: m.role, content: m.content})
            }
        }
        return history
    }

    // ──────────────────────────────────────────────────────────────
    // PROVIDER: OLLAMA (local, no API key)
    // POST http://localhost:11434/api/chat
    // ──────────────────────────────────────────────────────────────
    Process {
        id: ollamaProc
        command: ["sh", "-c", "echo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var data = this.text
                try {
                    var obj = JSON.parse(data.trim())
                    if (obj.message && obj.message.content) {
                        root.appendAssistant(obj.message.content)
                    } else if (obj.error) {
                        root.appendError("Ollama: " + obj.error)
                    } else {
                        root.appendError("Ollama: unexpected response")
                    }
                } catch(e) {
                    root.appendError("Ollama: " + data.trim())
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading) {
                root.appendError("Ollama: connection failed (exit " + exitCode + ")")
            }
        }
    }

    function sendOllama(text) {
        var history = buildChatHistory()
        var body = JSON.stringify({
            model: Settings.ollamaModel,
            messages: history,
            stream: false
        })
        ollamaProc.command = ["sh", "-c",
            "curl -s -m 120 -X POST " + Settings.ollamaEndpoint + "/api/chat "
          + "-H 'Content-Type: application/json' "
          + "-d '" + body.replace(/'/g, "'\\''") + "'"
        ]
        ollamaProc.running = true
    }

    // ──────────────────────────────────────────────────────────────
    // PROVIDER: GROQ (cloud, API key required)
    // POST https://api.groq.com/openai/v1/chat/completions
    // ──────────────────────────────────────────────────────────────
    Process {
        id: groqProc
        command: ["sh", "-c", "echo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._handleOpenAIResponse(this.text, "Groq")
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading) root.appendError("Groq: connection failed (exit " + exitCode + ")")
        }
    }

    function sendGroq(text) {
        if (!Settings.groqApiKey) { appendError("Groq: API key not set in Settings.qml"); return }
        var history = buildChatHistory()
        var body = JSON.stringify({
            model: Settings.groqModel,
            messages: history,
            stream: false
        })
        groqProc.command = ["sh", "-c",
            "curl -s -m 120 -X POST https://api.groq.com/openai/v1/chat/completions "
          + "-H 'Content-Type: application/json' "
          + "-H 'Authorization: Bearer " + Settings.groqApiKey + "' "
          + "-d '" + body.replace(/'/g, "'\\''") + "'"
        ]
        groqProc.running = true
    }

    // ──────────────────────────────────────────────────────────────
    // PROVIDER: OPENROUTER (cloud, API key required) — DEFAULT
    // POST https://openrouter.ai/api/v1/chat/completions
    // ──────────────────────────────────────────────────────────────
    Process {
        id: openrouterProc
        command: ["sh", "-c", "echo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._handleOpenAIResponse(this.text, "OpenRouter")
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading) root.appendError("OpenRouter: connection failed (exit " + exitCode + ")")
        }
    }

    function sendOpenRouter(text) {
        if (!Settings.openrouterApiKey) { appendError("OpenRouter: API key not set in Settings.qml"); return }
        var history = buildChatHistory()
        var body = JSON.stringify({
            model: Settings.openrouterModel,
            messages: history,
            stream: false
        })
        openrouterProc.command = ["sh", "-c",
            "curl -s -m 120 -X POST https://openrouter.ai/api/v1/chat/completions "
          + "-H 'Content-Type: application/json' "
          + "-H 'Authorization: Bearer " + Settings.openrouterApiKey + "' "
          + "-d '" + body.replace(/'/g, "'\\''") + "'"
        ]
        openrouterProc.running = true
    }

    // ── Shared OpenAI-compatible response parser (Groq + OpenRouter) ──
    function _handleOpenAIResponse(data, label) {
        try {
            var obj = JSON.parse(data.trim())
            if (obj.error) {
                appendError(label + ": " + (obj.error.message || JSON.stringify(obj.error)))
            } else if (obj.choices && obj.choices.length > 0 && obj.choices[0].message) {
                appendAssistant(obj.choices[0].message.content)
            } else {
                appendError(label + ": unexpected response format")
            }
        } catch(e) {
            appendError(label + ": " + data.trim())
        }
    }

    // ──────────────────────────────────────────────────────────────
    // PROVIDER: GEMINI (cloud, API key required)
    // POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
    // ──────────────────────────────────────────────────────────────
    Process {
        id: geminiProc
        command: ["sh", "-c", "echo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var data = this.text
                try {
                    var obj = JSON.parse(data.trim())
                    if (obj.error) {
                        root.appendError("Gemini: " + (obj.error.message || JSON.stringify(obj.error)))
                    } else if (obj.candidates && obj.candidates.length > 0
                               && obj.candidates[0].content
                               && obj.candidates[0].content.parts
                               && obj.candidates[0].content.parts.length > 0) {
                        root.appendAssistant(obj.candidates[0].content.parts[0].text)
                    } else {
                        root.appendError("Gemini: unexpected response format")
                    }
                } catch(e) {
                    root.appendError("Gemini: " + data.trim())
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading) root.appendError("Gemini: connection failed (exit " + exitCode + ")")
        }
    }

    function sendGemini(text) {
        if (!Settings.geminiApiKey) { appendError("Gemini: API key not set in Settings.qml"); return }

        // Convert chat history to Gemini format
        var contents = []
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            if (m.role === "user" || m.role === "assistant") {
                contents.push({
                    role: m.role === "assistant" ? "model" : "user",
                    parts: [{text: m.content}]
                })
            }
        }

        // Build request body with optional system instruction
        var reqBody = { contents: contents }
        if (Settings.aiSystemPrompt)
            reqBody.systemInstruction = { parts: [{text: Settings.aiSystemPrompt}] }

        var body = JSON.stringify(reqBody)
        var url = "https://generativelanguage.googleapis.com/v1beta/models/"
                + Settings.geminiModel + ":generateContent?key=" + Settings.geminiApiKey

        geminiProc.command = ["sh", "-c",
            "curl -s -m 120 -X POST '" + url + "' "
          + "-H 'Content-Type: application/json' "
          + "-d '" + body.replace(/'/g, "'\\''") + "'"
        ]
        geminiProc.running = true
    }

    // ── Response timeout ──
    Timer {
        id: timeoutTimer
        interval: 130000  // 130s (slightly above curl's 120s timeout)
        running: root.loading
        repeat: false
        onTriggered: {
            if (root.loading) {
                root.appendError("Request timed out. Check network or provider status.")
            }
        }
    }

    Component.onCompleted: {
        var d = new Date()
        clockStr = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
    }
}
