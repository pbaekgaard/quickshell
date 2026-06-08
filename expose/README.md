# expose

Mission-Control-style workspace overview with real per-workspace thumbnails. Triggered by IPC. Click a tile to jump, click a window inside the tile to focus it directly.

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ 一  01 [3 wins] │ 二  02 [1 win] │ 三  03 [—]    │
│ ┌──┐  ┌──┐     │ ┌────────┐     │                │
│ │ed│  │tm│     │ │firefox │     │      —         │
│ └──┘  └──┘     │ └────────┘     │                │
└──────────────┘  └──────────────┘  └──────────────┘
```

Each tile is a scaled-down screenshot of that workspace, captured the last time it was visible. The currently-active window in each workspace gets a 2px accent ring drawn at its real coordinates on top of the screenshot.

## Run

```sh
qs -n -d -c expose
```

Bind in Hyprland:

```
bind = SUPER, TAB, exec, qs -c expose ipc call expose toggle
```

## How the previews work

Wayland forbids a layer-shell client from screencapping arbitrary surfaces. So this module runs a small background daemon that:

1. Tails Hyprland's `.socket2.sock` event stream.
2. On any `workspace`, `workspacev2`, `focusedmon`, `openwindow`, `closewindow`, `movewindow`, `fullscreen`, or `changefloatingmode` event, restarts a 400ms debounce.
3. When the debounce fires, runs `grim -o <monitor> -s 0.35` for every monitor's currently active workspace and writes the result to `~/.cache/quickshell/expose/ws-<id>.png` (~50KB).

A workspace shows as a real screenshot once you've visited it at least once during this session. Never-visited workspaces show a fallback schematic view (faint indigo rectangles labeled with their window class). The active-window outline overlay works in both modes.

Captures also fire on every expose open, so the visible workspaces are always fresh.

### Privacy note

Screenshots of every workspace you switch to land in `~/.cache/quickshell/expose/`. They never leave your machine, but if you share a session via screen recording, password fields and chat history can end up in the cache. Clear with:

```sh
rm -rf ~/.cache/quickshell/expose
```

## IPC

```
qs -c expose ipc call expose toggle    # show + reload, or hide
qs -c expose ipc call expose show
qs -c expose ipc call expose hide
qs -c expose ipc call expose capture   # force a fresh capture of all visible workspaces
```

## Keyboard

| Key | Action |
| --- | --- |
| arrows / hjkl | move selection |
| Tab / Shift+Tab | next / previous |
| 1-9 | jump directly to that workspace |
| Enter, Space | jump to selected workspace |
| Esc, q | dismiss |

Click on the dim backdrop also dismisses. Hovering a tile selects it.

## Tile anatomy

- **Top band**: kanji workspace marker, two-digit id, monitor name (only when more than one monitor is attached), window count, and a pulsing accent dot if this workspace is the one currently active on its monitor.
- **Body**: cached `grim` screenshot fitted to monitor aspect. Falls back to a schematic view if no thumbnail exists.
- **Overlay**: a 2px accent ring at the position of the most-recently-focused window (lowest `focusHistoryID`).
- **Border**: accent if the tile is keyboard-selected, indigo if it's the currently-active workspace on its monitor, faint otherwise.

## Requirements

- `hyprctl` (Hyprland)
- `grim` for the thumbnails (Arch: `pacman -S grim`)
- `python3` for the event-socket listener
- `JetBrainsMono Nerd Font` (already pulled in by the desktop module)

If `grim` is missing the module still works, it just falls back to the schematic view permanently.

## Theming

Reads `~/.config/omarchy/current/theme/colors.toml` for `background`, `foreground`, `accent`, `color1`, `color7`, `color8`. Re-themes live on `omarchy theme set`. Serif for the kanji markers and overview title, JetBrainsMono for window class labels and badges.
