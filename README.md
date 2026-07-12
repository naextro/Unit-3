> [!WARNING]
> **Hyprland v0.55+ Lua migration** — This config uses legacy hyprlang syntax (supported until ~v0.57). Pin to v0.54 or wait for the Lua port. 

# Unit-3 (Forked from samyns/unit-3)

Hyprland + Quickshell + Waybar rice for Arch Linux, with a NieR:Automata aesthetic.





# SHOW OFF
https://github.com/user-attachments/assets/f3366b70-cfa0-46ef-b4f5-e461546364e2

## Quick install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/naextro/Unit-3/main/install.sh)
```
or
```
curl -fsSL https://raw.githubusercontent.com/naextro/Unit-3/main/install.sh | bash
```

## What's included

- **Window manager**: Hyprland with custom keybinds (QWERTY layout)
- **Shell/widgets**: Quickshell with custom QML widgets (menu, lockscreen, wallpaper picker, notifications, player)
- **Bar**: Waybar
- **Terminal**: Kitty
- **Theme**: NieR-inspired with custom video transitions
- **AI Chat Panel**: Custom AI chat panel supporting providers like Ollama, Gemini, Groq, OpenRouter

## Chat Panel

[#chat-panel](#chat-panel)

A NieR:Automata-style AI chat panel accessible via `SUPER + A`. Supports Ollama (local, no API key required), Groq, OpenRouter, and Google Gemini as providers, configurable in `Settings.qml`.

> [!NOTE]
> The Chat Panel is part of the main Quickshell shell and exposes an IPC target named `ai`. It can also be toggled from anywhere via `qs ipc call ai toggle`.

### Features

[#features-1](#features-1)

- **Multi-provider** — switch between `ollama`, `groq`, `openrouter`, and `gemini` via a single setting
- **Local-first option** — run fully offline against a local Ollama instance, no API key needed
- **Custom system prompt** — override the assistant's default behavior/persona
- **Configurable position & sizing** — anchored to the left edge, adjustable vertical position and font size

### Configuration

[#configuration-1](#configuration-1)

All options live in `Settings.qml` under the **AI PANEL** section:

| Setting | Description |
| --- | --- |
| `aiProvider` | Active provider: `"ollama"`, `"groq"`, `"openrouter"`, or `"gemini"` |
| `ollamaModel` / `ollamaEndpoint` | Local model name and Ollama server URL (default: `http://localhost:11434`) |
| `groqApiKey` / `groqModel` | Groq API key and model |
| `openrouterApiKey` / `openrouterModel` | OpenRouter API key and model (default provider) |
| `geminiApiKey` / `geminiModel` | Google Gemini API key and model |
| `aiSystemPrompt` | System prompt prepended to every request |
| `aiPanelPositionY` | Vertical position of the panel (`0.0` = top, `1.0` = bottom) |
| `aiPanelMarginLeft` | Distance from the left edge, in pixels |
| `aiChatFontSize` | Base font size for chat messages |


## Control Center

A NieR:Automata-style radial menu accessible via `SUPER + Tab`. The interface is built around a cross of four sub-menus orbiting a central node, with full keyboard navigation.

> [!NOTE]
> The Control Center is part of the main Quickshell shell and exposes an IPC target named `ctrl`. It can also be toggled from anywhere via `qs ipc call ctrl toggle`.

### Features

- **Connexion** — Wi-Fi & Bluetooth
  - Toggle radio on/off
  - Scan and connect to Wi-Fi networks with an inline password prompt (no external GUI)
  - List paired Bluetooth devices with connect/disconnect, pair, unpair, and live scan for new devices
- **Audio** — Output & Volume
  - Switch between PipeWire/PulseAudio sinks on the fly
  - Interactive volume slider (click to set, scroll to adjust, right-click to mute)
- **Quickshare** — Send & Receive (KDE Connect)
  - Pick files via a floating Yazi instance and send to paired devices
  - Pair/unpair devices directly from the panel, with a refresh button for discovery
  - Falls back to a clear "Install KDE Connect" prompt if missing
- **Notifications** — History & DND
  - Live history fed by the Quickshell notification daemon (no `mako`/`dunst` needed)
  - Click a notification once to expand (body, urgency, category, app, actions), click again to invoke the source app
  - Do Not Disturb toggle silences popups while preserving history
  - Pinned "Clear All" button

### Navigation

The menu uses two focus levels:

- **L1 — Overview**: navigate between the four slots and the center node
- **L3 — Settings**: focus inside a sub-menu (sub-item + first action are focused simultaneously)

| Key | Action |
|---|---|
| `W` / `↑` | Move up (or scroll up in lists) |
| `A` / `←` | Move left (or scroll left in actions) |
| `S` / `↓` | Move down (or scroll down in lists) |
| `D` / `→` | Move right (or scroll right in actions) |
| `Enter` / `Space` | Activate focused action (or expand a notification) |
| `Esc` | Back to center (or close menu) |

**From the center node**, pressing any direction enters the corresponding sub-menu directly (no double-press). **From a slot**, pressing the same direction enters its settings; pressing the opposite direction returns to center.

When you focus a sub-menu, the whole cross slides ("pulls the tablecloth") to bring the focused panel closer to the center, while the other slots dim but stay visible.


## Customization

Personal overrides go in `~/.config/hypr/user.conf` — this file is **never** overwritten by updates.

Example:
monitor = DP-1, 2560x1440@144, 0x0, 1
input { kb_layout = us }
bind = SUPER, B, exec, firefox

## Keybinds

| Key | Action |
|-----|--------|
| `SUPER` (tap) | Open app menu |
| `SUPER + Tab` | Toggle Control Center |
| `SUPER + B` | Browser (tries zen, then firefox) |
| `SUPER + A` | Ai Chat Panel |
| `SUPER + L` | Lockscreen |
| `SUPER + T` | Terminal (kitty) |
| `SUPER + Return` | Toggle Quickshell player |
| `SUPER + P` | Wallpaper picker |
| `SUPER + Q` | Close window |
| `SUPER + F` | Fullscreen |
| `ALT + Tab` | Cycle windows |
| `ALT + 1/2/3/...` | Switch workspace (QWERTY) |
| `Print` | Screenshot |
| `ALT SHIFT + S` | Region screenshot |

## Credits

Inspired by [caelestia-dots/shell](https://github.com/caelestia-dots/shell).

Inspired by https://github.com/flickowoa/dotfiles.git 

Forked from https://github.com/samyns/Unit-3
## License
MIT