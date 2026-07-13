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
    property bool   pinned: true
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
    property bool allowRoot: false

    // ── Display messages — splits assistant code blocks into separate visual segments ──
    property var displayMessages: {
        var result = []
        for (var i = 0; i < root.messages.length; i++) {
            var parts = root.splitMessageForDisplay(root.messages[i])
            for (var j = 0; j < parts.length; j++) {
                result.push(parts[j])
            }
        }
        return result
    }

    function splitMessageForDisplay(msg) {
        if (msg.role !== "assistant") return [msg]

        var result = []
        var text = msg.content
        var i = 0
        var current = ""

        while (i < text.length) {
            // Check for triple backtick (fenced code block)
            if (text.substring(i, i + 3) === "```") {
                var closeIdx3 = text.indexOf("```", i + 3)
                if (closeIdx3 !== -1) {
                    if (current.trim() !== "") {
                        result.push({role: "assistant", content: current.trim(), isCode: false})
                    }
                    current = ""
                    var codeContent3 = text.substring(i + 3, closeIdx3)
                    var langTag = ""
                    var firstNewline = codeContent3.indexOf("\n")
                    if (firstNewline !== -1) {
                        var possibleLang = codeContent3.substring(0, firstNewline).trim()
                        if (possibleLang.length <= 20 && possibleLang.indexOf(" ") === -1) {
                            langTag = possibleLang
                            codeContent3 = codeContent3.substring(firstNewline + 1)
                        }
                    }
                    if (codeContent3.trim() !== "") {
                        result.push({role: "assistant", content: codeContent3, isCode: true, lang: langTag})
                    }
                    i = closeIdx3 + 3
                    continue
                }
            }
            // Check for double backtick
            if (text.substring(i, i + 2) === "``") {
                var closeIdx2 = text.indexOf("``", i + 2)
                if (closeIdx2 !== -1) {
                    if (current.trim() !== "") {
                        result.push({role: "assistant", content: current.trim(), isCode: false})
                    }
                    current = ""
                    var codeContent2 = text.substring(i + 2, closeIdx2)
                    if (codeContent2.trim() !== "") {
                        result.push({role: "assistant", content: codeContent2.trim(), isCode: true, lang: ""})
                    }
                    i = closeIdx2 + 2
                    continue
                }
            }
            // Check for single backtick
            if (text[i] === '`') {
                var closeIdx1 = text.indexOf("`", i + 1)
                if (closeIdx1 !== -1) {
                    if (current.trim() !== "") {
                        result.push({role: "assistant", content: current.trim(), isCode: false})
                    }
                    current = ""
                    var codeContent1 = text.substring(i + 1, closeIdx1)
                    if (codeContent1.trim() !== "") {
                        result.push({role: "assistant", content: codeContent1.trim(), isCode: true, lang: ""})
                    }
                    i = closeIdx1 + 1
                    continue
                }
            }
            current += text[i]
            i++
        }
        if (current.trim() !== "") {
            result.push({role: "assistant", content: current.trim(), isCode: false})
        }
        return result.length > 0 ? result : [msg]
    }

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
                            duration: 22000; loops: Animation.Infinite; running: root.shown
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

                        // Warn button
                        Item {
                            id: warnBtn
                            width: s(28)
                            height: s(14)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                color: root.allowRoot 
                                    ? Qt.rgba(200/255, 112/255, 96/255, 0.15)
                                    : (warnMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.04) : "transparent")
                                border.width: 1
                                border.color: root.allowRoot
                                    ? Qt.rgba(200/255, 112/255, 96/255, 0.6)
                                    : (warnMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.4) : Qt.rgba(200/255, 184/255, 154/255, 0.12))

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "WARN"
                                font.family: "Share Tech Mono"
                                font.pixelSize: s(7)
                                font.letterSpacing: 1
                                color: root.allowRoot
                                    ? Qt.rgba(200/255, 112/255, 96/255, 0.95)
                                    : (warnMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.6) : Qt.rgba(200/255, 184/255, 154/255, 0.25))

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: warnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.allowRoot = !root.allowRoot
                            }
                        }

                        // Export button
                        Item {
                            id: exportBtn
                            width: s(34)
                            height: s(14)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                color: exportMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.04) : "transparent"
                                border.width: 1
                                border.color: exportMa.containsMouse
                                    ? Qt.rgba(200/255, 184/255, 154/255, 0.4)
                                    : Qt.rgba(200/255, 184/255, 154/255, 0.12)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "EXPORT"
                                font.family: "Share Tech Mono"
                                font.pixelSize: s(7)
                                font.letterSpacing: 1
                                color: exportMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.6) : Qt.rgba(200/255, 184/255, 154/255, 0.25)

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: exportMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.exportChat()
                            }
                        }

                        // Clear button
                        Item {
                            id: clearBtn
                            width: s(30)
                            height: s(14)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                color: clearMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.04) : "transparent"
                                border.width: 1
                                border.color: clearMa.containsMouse
                                    ? Qt.rgba(200/255, 184/255, 154/255, 0.4)
                                    : Qt.rgba(200/255, 184/255, 154/255, 0.12)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "CLEAR"
                                font.family: "Share Tech Mono"
                                font.pixelSize: s(7)
                                font.letterSpacing: 1
                                color: clearMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.6) : Qt.rgba(200/255, 184/255, 154/255, 0.25)

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: clearMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.clearChat()
                            }
                        }

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
                                model: root.displayMessages.length
                                delegate: Item {
                                    id: msgDelegate
                                    required property int index
                                    width: msgCol.width
                                    height: msgBubble.implicitHeight + s(6)

                                     property var msg: root.displayMessages[index]
                                     property bool isUser: msg.role === "user"
                                     property bool isError: msg.role === "error"
                                     property bool isCode: msg.isCode === true

                                     readonly property int bubblePaddingH: isUser ? s(9) : s(11)
                                     readonly property int bubblePaddingB: isUser ? s(8) : s(10)
                                     readonly property int labelTopMargin: s(4)
                                     readonly property int textTopMargin: s(3)

                                    HoverHandler {
                                        id: msgHover
                                    }

                                    Rectangle {
                                        id: msgBubble
                                        width: Math.min(
                                            Math.max(
                                                msgText.implicitWidth + (msgDelegate.bubblePaddingH * 2),
                                                roleLabel.implicitWidth + (msgDelegate.bubblePaddingH * 2)
                                            ),
                                            parent.width * 0.88
                                        )
                                        implicitHeight: msgDelegate.labelTopMargin + roleLabel.implicitHeight + msgDelegate.textTopMargin + msgText.implicitHeight + msgDelegate.bubblePaddingB
                                        anchors.right: msgDelegate.isUser ? parent.right : undefined
                                        anchors.left:  msgDelegate.isUser ? undefined : parent.left
                                        color: msgDelegate.isError
                                            ? Qt.rgba(200/255, 112/255, 96/255, 0.1)
                                            : msgDelegate.isCode
                                                ? Qt.rgba(30/255, 35/255, 42/255, 0.95)
                                                : msgDelegate.isUser
                                                    ? Qt.rgba(200/255,184/255,154/255,0.08)
                                                    : Qt.rgba(96/255,168/255,128/255,0.06)
                                        border.width: 1
                                        border.color: msgDelegate.isError
                                            ? Qt.rgba(200/255, 112/255, 96/255, 0.3)
                                            : msgDelegate.isCode
                                                ? Qt.rgba(96/255, 140/255, 180/255, 0.2)
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
                                            text: msgDelegate.isError ? "ERR"
                                                : msgDelegate.isUser ? "OPERATOR"
                                                : msgDelegate.isCode ? ("CODE" + (msgDelegate.msg.lang ? " // " + msgDelegate.msg.lang.toUpperCase() : ""))
                                                : "AI"
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(6)
                                            font.letterSpacing: 1.5
                                            color: msgDelegate.isError
                                                ? Qt.rgba(200/255, 112/255, 96/255, 0.6)
                                                : msgDelegate.isCode
                                                    ? Qt.rgba(96/255, 140/255, 180/255, 0.5)
                                                    : msgDelegate.isUser
                                                        ? Qt.rgba(200/255,184/255,154/255,0.35)
                                                        : Qt.rgba(96/255,168/255,128/255,0.45)
                                        }

                                        TextEdit {
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
                                            textFormat: (msgDelegate.isUser || msgDelegate.isError || msgDelegate.isCode)
                                                ? TextEdit.PlainText
                                                : TextEdit.MarkdownText
                                            readOnly: true
                                            selectByMouse: true
                                            persistentSelection: true
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(Settings.aiChatFontSize)
                                            font.letterSpacing: 0.5
                                            color: msgDelegate.isError
                                                ? Qt.rgba(200/255, 112/255, 96/255, 0.8)
                                                : msgDelegate.isCode
                                                    ? Qt.rgba(160/255, 190/255, 220/255, 0.85)
                                                    : Qt.rgba(200/255,184/255,154/255,0.75)
                                            selectionColor: Qt.rgba(200/255,184/255,154/255,0.25)
                                            wrapMode: Text.WordWrap
                                            // TextEdit has no lineHeight prop; approximate via font
                                        }
                                    }

                                    // Copy Button placed outside the msgBubble
                                    Item {
                                        id: copyBtn
                                        width: s(34)
                                        height: s(14)

                                        anchors.verticalCenter: msgBubble.verticalCenter
                                        anchors.right: msgDelegate.isUser ? msgBubble.left : undefined
                                        anchors.left: msgDelegate.isUser ? undefined : msgBubble.right
                                        anchors.rightMargin: msgDelegate.isUser ? s(6) : undefined
                                        anchors.leftMargin: msgDelegate.isUser ? undefined : s(6)

                                        opacity: (msgHover.hovered || copyBtnMa.containsMouse || copiedTimer.running) ? 1.0 : 0.0
                                        visible: opacity > 0.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }

                                        property bool copied: false

                                        Rectangle {
                                            anchors.fill: parent
                                            color: copyBtnMa.containsMouse
                                                ? Qt.rgba(200/255, 184/255, 154/255, 0.08)
                                                : (copyBtn.copied ? Qt.rgba(96/255, 168/255, 128/255, 0.1) : "transparent")
                                            border.width: 1
                                            border.color: copyBtn.copied
                                                ? Qt.rgba(96/255, 168/255, 128/255, 0.5)
                                                : (copyBtnMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.4) : Qt.rgba(200/255, 184/255, 154/255, 0.12))

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: copyBtn.copied ? "COPIED" : "COPY"
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: s(6)
                                            font.letterSpacing: 1
                                            color: copyBtn.copied
                                                ? Qt.rgba(96/255, 168/255, 128/255, 0.95)
                                                : (copyBtnMa.containsMouse ? Qt.rgba(200/255, 184/255, 154/255, 0.75) : Qt.rgba(200/255, 184/255, 154/255, 0.3))

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Timer {
                                            id: copiedTimer
                                            interval: 2000
                                            onTriggered: copyBtn.copied = false
                                        }

                                        MouseArea {
                                            id: copyBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                Quickshell.clipboardText = msgDelegate.msg.content
                                                copyBtn.copied = true
                                                copiedTimer.restart()
                                            }
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
                                            running: root.loading && root.shown; loops: Animation.Infinite
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
                                            running: root.loading && root.shown; loops: Animation.Infinite
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
                                    running: root.loading && root.shown; loops: Animation.Infinite
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
        interval: 1000; running: root.shown; repeat: true
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
            var d = new Date()
            root.clockStr = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
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

        // Dispatch to unified agent
        sendToAgent()
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

    function clearChat() {
        root.messages = []
    }

    function exportChat() {
        if (root.messages.length === 0) return
        
        var d = new Date()
        var pad = function(n) { return String(n).padStart(2, '0') }
        var timestamp = d.getFullYear() + pad(d.getMonth()+1) + pad(d.getDate()) + "_" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds())
        var filepath = "$HOME/YoRHa-Logs/log_" + timestamp + ".md"
        
        var md = "# YoRHa // TACTICAL AI CHAT LOG\n"
        md += "Timestamp: " + d.toLocaleString() + "\n"
        md += "Provider: " + Settings.aiProvider.toUpperCase() + "\n"
        md += "Model: " + Settings.aiModel.toUpperCase() + "\n\n"
        md += "========================================================\n\n"
        
        for (var i = 0; i < root.messages.length; i++) {
            var m = root.messages[i]
            var sender = m.role === "user" ? "OPERATOR" : (m.role === "error" ? "SYSTEM ERROR" : "AI")
            md += "### [ " + sender + " ]\n\n" + m.content + "\n\n"
        }
        
        var escapedMd = md.replace(/'/g, "'\\''")
        var cmd = "mkdir -p $HOME/YoRHa-Logs && echo '" + escapedMd + "' > " + filepath
        
        exportProc.command = ["sh", "-c", cmd]
        exportProc.running = true
    }

    Process {
        id: agentProc
        command: ["sh", "-c", "echo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var data = this.text.trim()
                if (data.indexOf("Connection failed:") === 0 || data.indexOf("Error:") === 0) {
                    root.appendError(data)
                } else {
                    root.appendAssistant(data)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading && exitCode !== 0) {
                root.appendError("Agent execution failed (exit " + exitCode + ")")
            }
        }
    }

    Process {
        id: exportProc
        command: ["sh", "-c", "echo"]
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                notifyProc.command = ["notify-send", "LOG ARCHIVED", "Tactical log successfully saved to YoRHa archives.", "--icon=dialog-information"]
                notifyProc.running = true
            } else {
                notifyProc.command = ["notify-send", "EXPORT FAILED", "Failed to save tactical log.", "--icon=dialog-error"]
                notifyProc.running = true
            }
        }
    }

    Process {
        id: notifyProc
        command: ["sh", "-c", "echo"]
        running: false
    }

    function sendToAgent() {
    var provider = Settings.aiProvider
    var model = Settings.aiModel
    var apiKey = ""
    if (provider === "groq") apiKey = Settings.groqApiKey
    else if (provider === "openrouter") apiKey = Settings.openrouterApiKey
    else if (provider === "gemini") apiKey = Settings.geminiApiKey

    var endpoint = Settings.ollamaEndpoint
    var systemPrompt = Settings.aiSystemPrompt

    var history = []
    for (var i = 0; i < root.messages.length; i++) {
        var m = root.messages[i]
        if (m.role === "user" || m.role === "assistant") {
            history.push({role: m.role, content: m.content})
        }
    }

    var historyStr = JSON.stringify(history)

    // Resolve relative to the running shell config, not a hardcoded username/path
    var scriptPath = Quickshell.shellDir + "/scripts/ai_agent.py"

    var args = [
        scriptPath,
        "--provider", provider,
        "--model", model,
        "--history", historyStr
    ]

    if (apiKey) args.push("--api-key", apiKey)
    if (endpoint) args.push("--endpoint", endpoint)
    if (systemPrompt) args.push("--system-prompt", systemPrompt)
    if (root.allowRoot) args.push("--allow-root")

    agentProc.command = args
    agentProc.running = true
}

    // ── Response timeout ──
    Timer {
        id: timeoutTimer
        interval: 130000
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