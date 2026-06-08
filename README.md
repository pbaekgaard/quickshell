# quickshell

Personal [Quickshell](https://quickshell.outfoxxed.me) configs built for [omarchy](https://omarchy.org). They read the live omarchy palette at `~/.config/omarchy/current/theme/colors.toml`, so the bar and overlay restyle themselves whenever you run `omarchy theme set <name>`.



https://github.com/user-attachments/assets/a5bf641b-ccff-41bd-a14c-619ed5c3321a



| Module | What it does |
| --- | --- |
| [`desktop/`](./desktop) | Top bar plus omni-menu command palette in a single Quickshell process. Kanagawa Dragon layout on the live omarchy palette, kanji workspace markers, click-through popups for calendar / screenshots / display / weather / aether blueprints, and a fused command palette over installed apps and the omarchy-menu (synonyms — "wallpaper" finds Background, "reboot" finds Restart). |
| [`song-drop/`](./song-drop) | MPRIS notifier. Drops a liquid blob from the bar on track change, morphs into a song-title pill, holds, then retreats. |
| [`song-slide/`](./song-slide) | MPRIS notifier, snappier sibling of song-drop. Slides a sharp-cornered card in from the right with title, artist, an accent stripe, and a flush bottom-edge progress bar. Cross-fades content on rapid track changes instead of restarting the slide. |
| [`theme-wash/`](./theme-wash) | Theme-swap flourish. On `omarchy theme set <name>`, washes the new accent across the bar from an alternating corner like ink spilling in water, with the old accent pulsing out from the centre and the new theme's name popping briefly mid-wash. |
| [`music-wallpaper/`](./music-wallpaper) | Music-reactive wallpaper. Reads `cliamp visstream` NDJSON, paints a soft radial pulse with mids halo, bass-transient ripples, and a low-opacity EQ across the bottom. Tints to the omarchy accent. |
| [`clipboard-ripple/`](./clipboard-ripple) | Clipboard tactile feedback. `wl-paste --watch` blooms a soft accent-tinted halo outward from the cursor while a brighter inner core pulses twice. Click-through overlay. |
| [`battery-drip/`](./battery-drip) | Rare, high-information battery feedback. Crossings of 20% / 10% drip a teardrop down the right edge of the bar; transition to Full (or plug-in already near full) fills a battery outline with a rising sinusoidal wave. Click-through overlay. |
| [`quickapps/`](./quickapps) | Radial quick-app launcher. Eight to ten favourite apps arranged around a single faint indigo ring with kanji counter and serif typography. Reads `~/.config/omarchy-quickapps/apps.json`; bind to a Hyprland key for a Spotlight-style launch. |
| [`screensaver/`](./screensaver) | Fullscreen shader screensaver with a retro-computing / hacker bent. Eleven GLSL programs (plasma, fluid, transparent CRT overlay, digital rain, xxd hex dump, stack-smash visualiser, Space Invaders attract, DOOM fire, fake terminal, Mr. Robot hacking sequence, Conway's Life) cross-fade on a 22 s cycle, all tinted live from the omarchy palette. Life uses a recursive ShaderEffectSource for cell-state feedback; the rest are stateless. IPC-triggered: `qs -c screensaver ipc call saver toggle`. Any input dismisses; `1`-`9` jumps directly, Tab cycles, `ipc call saver pick 9` / `pick 10` selects the over-flow slots. |
| [`backgrounds/`](./backgrounds) | Subtle fluid-shader wallpaper. Ten low-contrast GLSL backgrounds (drift, veil, mist, ripple, silk, caustics, breath, smoke, dunes, aurora) cycle every 90 s with a 4 s cross-fade, all tinted from the omarchy palette. Runs on the Wayland Background layer in place of omarchy's wallpaper. IPC: `qs -c backgrounds ipc call bg next \| pick N \| hold \| cycle \| reload`. |
| [`winamp-background/`](./winamp-background) | Classic Winamp 2.x LED-matrix spectrum analyser as a wallpaper. Reads `cliamp visstream` NDJSON, renders 64 stacked-block bars with a green/yellow/red gradient and falling peak markers. Sits on the Wayland Background layer. |
| [`gamehud/`](./gamehud) | Cockpit HUD pinned top-right that fades in only while a game-class window is focused. Tails Hyprland's `.socket2.sock` for `activewindow` events and matches the class against a regex list (override at `~/.config/quickshell/gamehud/games.json`). Surfaces CPU%, RAM, and Nvidia GPU util / temp / power; click-through via empty input region so the game keeps mouse and keyboard. IPC: `qs -c gamehud ipc call hud show \| hide \| toggle \| peek \| reloadConfig`. |
| [`expose/`](./expose) | Mission-Control-style workspace overview with real thumbnails. A background daemon tails Hyprland's socket2 and runs `grim -o <mon> -s 0.35` on a 400ms debounce after workspace/window events, caching each workspace as `~/.cache/quickshell/expose/ws-N.png`. The IPC-triggered overlay tiles those screenshots in a grid, with a 2px accent ring drawn over the most-recently-focused window in each. Workspaces never visited this session fall back to a schematic view. Arrow keys / hjkl / Tab navigate, 1-9 jumps, click a window to focus it directly. IPC: `qs -c expose ipc call expose toggle`. Requires `grim`. |

Each module is a self-contained Quickshell config rooted at `shell.qml`.

## Quick start

```sh
git clone https://github.com/bjarneo/quickshell ~/.config/quickshell

# disable omarchy's waybar (one-shot toggle, also bound to SUPER+SHIFT+SPACE)
omarchy toggle waybar

# launch the bar + omni-menu daemon
qs -n -d -c desktop
# then toggle the palette from a Hyprland keybind:
#   bind = SUPER, SPACE, exec, qs -c desktop ipc call palette toggle

# launch the song-drop overlay
qs -n -d -c song-drop

# launch the song-slide overlay (snappier sibling, anchored right)
qs -n -d -c song-slide

# launch the theme-wash flourish
qs -n -d -c theme-wash

# launch the music-reactive wallpaper (requires cliamp)
qs -n -d -c music-wallpaper

# launch the clipboard ripple
qs -n -d -c clipboard-ripple

# launch the battery drip / fill overlay
qs -n -d -c battery-drip

# launch the quickapps radial launcher (bind to a key, no daemon needed)
qs -n -c quickapps

# launch the screensaver daemon, then trigger / dismiss it via IPC
qs -n -d -c screensaver
# toggle from a Hyprland keybind:
#   bind = SUPER, F12, exec, qs -c screensaver ipc call saver toggle

# launch the fluid-shader wallpaper (replaces omarchy's wallpaper)
qs -n -d -c backgrounds
# pick a specific one or pause cycling:
#   qs -c backgrounds ipc call bg pick 4
#   qs -c backgrounds ipc call bg hold

# launch the game-mode HUD (auto-shows on game-class focus)
qs -n -d -c gamehud
# manual toggle:
#   bind = SUPER SHIFT, G, exec, qs -c gamehud ipc call hud toggle

# launch the workspace exposé (IPC-triggered)
qs -n -d -c expose
# bind to a Hyprland key:
#   bind = SUPER, TAB, exec, qs -c expose ipc call expose toggle
```

`-c <name>` resolves to `~/.config/quickshell/<name>/shell.qml`. `-d` daemonizes, `-n` makes it idempotent.

For per-module setup (autostart hooks, theme reactivity details, customization knobs, troubleshooting), see [`desktop/README.md`](./desktop/README.md).

## Requirements

- quickshell
- hyprland
- omarchy (for the live theme palette and the `omarchy toggle waybar` flow)

desktop also wants `pamixer`, `bluetoothctl`, and `nmcli` for telemetry tiles, plus `brightnessctl` and `hyprsunset` for the display popup and `jq` + `curl` for the weather popup. song-drop only needs an MPRIS-capable player (mpv, spotify, etc.). music-wallpaper needs [`cliamp`](https://github.com/bjarneo/cliamp) on `PATH` for its `visstream` NDJSON feed. clipboard-ripple needs `wl-clipboard` (for `wl-paste`) and `python3` for the cursor/monitor query.

## License

MIT.
