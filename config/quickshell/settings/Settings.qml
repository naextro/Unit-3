pragma Singleton
import QtQuick
import Quickshell

// ╔══════════════════════════════════════════════════════════════╗
// ║  SETTINGS — configuration options for the NieR rice          ║
// ║  Edit the values here to customize the behavior              ║
// ╚══════════════════════════════════════════════════════════════╝

QtObject {

    // ── GLOBAL SCALE ─────────────────────────────────────────────

    // Global multiplier applied to all sizes
    // 1.0 = normal size, 1.25 = 25% larger, 0.8 = 20% smaller
    readonly property real scale: 1

    // Main screen dimensions (equivalent to 100vw / 100vh)
    readonly property real screenW: Quickshell.screens.length > 0
                                    ? Quickshell.screens[0].width  : 1920
    readonly property real screenH: Quickshell.screens.length > 0
                                    ? Quickshell.screens[0].height : 1080

    // Relative units — usage: Settings.vw(5) = 5% of screen width
    // CSS equivalent: 5vw
    function vw(pct) { return Math.round(screenW * pct / 100) }
    function vh(pct) { return Math.round(screenH * pct / 100) }

    // Scaled unit — applies scale on top of the base size
    // Usage: Settings.s(320) = 320 * scale
    function s(px)   { return Math.round(px * scale) }

    // ── PLAYER ──────────────────────────────────────────────────

    // Player background: true = opaque dark background / false = transparent
    readonly property bool playerBackground: true

    // Background color (used only if playerBackground = true)
    readonly property color playerBgColor: Qt.rgba(11/255, 10/255, 9/255, 0.92)

    // Vertical position of the player (0.0 = top, 1.0 = bottom of screen)
    readonly property real playerPositionY: 0.39

    // Distance from the right edge in pixels
    readonly property int playerMarginRight: s(20)

    // Player width in pixels (automatically scaled)
    readonly property int playerWidth: s(320)


    // ── COMPANIONS ──────────────────────────────────────────────

    readonly property bool companionsEnabled: true  // Show companions

    // Distance from the right edge in pixels
    readonly property int companionsMarginRight: s(20)

    // Sprite size
    readonly property int companionsSpriteSize: s(128)


    // ── GLOBAL COLORS ─────────────────────────────────────────────

    // NieR sepia palette (do not modify unless changing the theme)
    readonly property color fg:   "#c8b89a"      // main text
    readonly property color bg:   "#0b0a09"      // main background
    readonly property color a1:   "#c87060"      // red accent
    readonly property color a2:   "#60a880"      // green accent
    readonly property color a3:   "#6090c8"      // blue accent
    readonly property color a4:   "#c8a860"      // gold accent
    readonly property color ln:   Qt.rgba(200/255, 184/255, 154/255, 0.12)  // thin border
    readonly property color lnm:  Qt.rgba(200/255, 184/255, 154/255, 0.22) // medium border
    readonly property color curtainColor: "#c8b89a"  // wipe curtain color


    // ── ANIMATIONS ──────────────────────────────────────────────

    // Reveal duration (ms)
    readonly property int revealDuration: 460

    // Hide duration (ms)
    readonly property int hideDuration: 380

    // Blocky cover transition duration (ms per step)
    readonly property int coverTransitionStep: 30


    // ── WAYBAR ──────────────────────────────────────────────────

    // Waybar height in pixels
    readonly property int waybarHeight: 28


    // ── AI PANEL ────────────────────────────────────────────────

    // Active provider: "ollama" | "groq" | "openrouter" | "gemini"
    readonly property string aiProvider: "openrouter"

    // Ollama — local model, no API key required
    readonly property string ollamaModel:    "llama3.2"
    readonly property string ollamaEndpoint: "http://localhost:11434"

    // Groq — cloud, requires API key
    readonly property string groqApiKey: ""
    readonly property string groqModel: "llama-3.1-8b-instant"//"openai/gpt-oss-120b" 

    // OpenRouter — cloud, DEFAULT provider
    readonly property string openrouterApiKey: ""
    readonly property string openrouterModel:  "openrouter/free"
    
    // Cereberas cz why not
    readonly property string cerebrasApiKey: ""
    readonly property string cerebrasModel:  "gpt-oss-120b"

    // Gemini — cloud, requires API key
    readonly property string geminiApiKey: ""
    readonly property string geminiModel:  "gemma-4-31b-it"

    // Convenience: returns the model name for the active provider
    readonly property string aiModel: {
        if (aiProvider === "ollama")      return ollamaModel
        if (aiProvider === "groq")        return groqModel
        if (aiProvider === "openrouter")  return openrouterModel
        if (aiProvider === "gemini")      return geminiModel
        if (aiProvider === "cerebras")    return cerebrasModel
        return "unknown"
    }

    // System prompt — prepended as a system message on every AI request
    readonly property string aiSystemPrompt: "You are a helpful AI assistant integrated into a NieR-themed Hyprland desktop shell (Quickshell), a compact side panel. Be concise.\n\nMarkdown: headings, bold/italic/strikethrough, blockquotes, lists, tables, links, and triple-backtick code blocks are supported. Single backticks are NOT supported, never use them. Write filenames, commands, and variable names as plain text instead.\n\nNever use horizontal rules or footnotes.\n\nCRITICAL - ZERO TOLERANCE FOR FABRICATION: Before stating ANY fact about the system, file, process, config, or command output, ask yourself: did a tool call in THIS conversation actually return this exact information? If you have not called a tool and seen its real output, you do not know it, guessing is not permitted under any circumstance. Never invent file paths, filenames, PIDs, process names, config contents, timestamps, or command output, even if they seem plausible or typical for this kind of system. Never present reasoning, assumptions, or pattern-matched guesses as observed fact. If you have not verified something with a tool call, either call the tool now or explicitly say you have not checked and don't know. When reviewing your own draft response before sending it, re-check every specific claim (paths, names, numbers, statuses) against actual tool output from this conversation, and delete or rewrite anything you cannot trace back to a real result."    
    // AI panel vertical position (0.0 = top, 1.0 = bottom)    
    readonly property real aiPanelPositionY: 0.10

    // Distance from the left edge in pixels
    readonly property int aiPanelMarginLeft: s(20)

    // Font size for chat messages in pixels (base size before scaling)
    readonly property int aiChatFontSize: 15



}
