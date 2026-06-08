# quickapps2

A hexagonal HUD-style quick-app launcher for [omarchy](https://omarchy.org). Pointy-top hex tiles arrayed around a central readout hexagon, faint hex-grid wash across the screen, corner brackets, and monospace tactical-display typography. Colours follow the live omarchy palette, so it restyles itself whenever you run `omarchy theme set <name>`.

This is the sibling of `quickapps/` (the zen/serif/kanji variant). Layout, palette source, and keybindings are the same; the visual language is HUD instead of zen.

## Quick start

```sh
# Hyprland keybind (bindings.lua):
hl.bind("SUPER + A", hl.dsp.exec_cmd("qs -n -c quickapps2"), { description = "Quick apps (hex)" })

# Or run it directly.
qs -n -c quickapps2
```

The overlay grabs keyboard focus and exits on app launch or Esc.

## Configuration

Edit `~/.config/omarchy-quickapps2/apps.json`. Falls back to `~/.config/omarchy-quickapps/apps.json` (the same roster the sibling launcher uses), then to `quickapps.example.json` shipped here. Drop the dedicated file in if you want a different set of apps in this launcher.

```json
{
  "apps": [
    { "name": "TERMINAL", "icon": "ghostty",  "exec": "ghostty" },
    { "name": "BROWSER",  "icon": "chromium", "exec": "chromium" },
    { "name": "EDITOR",   "icon": "nvim",     "exec": "omarchy-launch-or-focus-tui nvim" }
  ]
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `name` | yes | Rendered uppercase under each tile and inside the central readout. Keep it short. |
| `icon` | no | Icon theme name or absolute path. Resolved via `Quickshell.iconPath()`. Falls back to the first letter of `name` if unresolved. |
| `exec` | yes | Run as `setsid -f sh -c "<exec>"`. |
| `comment` | no | Sub-label under the centred app name in the readout. Falls back to `exec`. |

Six to ten entries look best on the ring. Tile angles are evenly spaced regardless of count.

## Keys

| Key | Action |
| --- | --- |
| Left / Right / H / L / Up / Down / J / K | Rotate selection |
| Tab / Shift+Tab | Rotate selection |
| Scroll wheel | Rotate selection |
| 1 to 9 | Jump to and launch the nth app |
| Home / End | Jump to first / last |
| Enter / Space | Launch the selected app |
| Esc / Q | Dismiss |
| Click outside a tile | Dismiss |
| Click a tile | Select and launch |

## Theme reactivity

Reads `~/.config/omarchy/current/theme/colors.toml`. Role mapping is the same as `quickapps/`:

| toml key | role |
| --- | --- |
| `background` | overlay base, focused-tile text fill |
| `foreground` | primary readout text, focused tile fill |
| `color7` | secondary readout text |
| `color8` | muted labels, frame ticks |
| `accent` | idle hex stroke, grid wash, corner brackets |
| `color1` | active marker, alert pip, EXECUTE hint |

Theme swaps survive the inode shuffle the same way the sibling does: a second `FileView` watches `theme.name` and reloads the palette when omarchy-theme-set replaces the theme dir.

## Layout

- Pointy-top hex tiles, drawn on `Canvas` so the shape stays crisp at any palette and DPI.
- Tiles arrayed on a single ring at radius 240, evenly spaced for the current app count.
- Central hex (double outline) holds the selected app name, accent divider, and comment/exec line.
- Faint full-screen hex-grid wash at 5% accent alpha, four HUD corner brackets, status header with blinking alert pip ("QUICK//LAUNCH" / "NODES nn"), and a top-right SLOT counter (`07 / 12`).
- Footer is a tactical key strip: `[<>] ROTATE | [1-9] JUMP | [ENT] EXECUTE | [ESC] ABORT`.
- Typography is monospace throughout, no italic, no kanji. The sibling launcher keeps the zen serif look.

## Files

```
quickapps2/
  shell.qml                # entry point
  quickapps.example.json   # sample apps list
  README.md
```
