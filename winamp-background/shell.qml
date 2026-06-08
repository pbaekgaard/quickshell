import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Winamp-style spectrum analyser wallpaper. Sits on the Wayland Background
// layer and renders the classic LED-block bargraph driven by cliamp's
// visstream NDJSON. Each bar is a stack of discrete segments (bottom = green,
// middle = yellow, top = red) with a "peak" marker that falls slowly — the
// iconic Winamp 2.x look. Bars span the full screen edge to edge.
ShellRoot {
    id: root

    // ---------- Theme ----------
    // Winamp's bargraph is colour-anchored (green/yellow/red), so we don't
    // re-tint the bars from the omarchy palette. We do pull the background
    // base so the wallpaper still feels like part of the desktop.
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    property color bgColor: "#000000"

    // Classic Winamp bargraph tints.
    readonly property color cGreen:  "#00ff66"
    readonly property color cYellow: "#f7d046"
    readonly property color cRed:    "#ff2a2a"
    readonly property color cPeak:   "#ffffff"

    // ---------- Audio ----------
    property var bands: []
    property var smoothBands: []
    property var peaks: []          // peak hold value per bar (0..1)
    property var peakVel: []        // peak fall velocity per bar
    readonly property int segments: 28  // LED rows per bar

    // ---------- Stale-frame silence detection ----------
    // cliamp emits a frozen frame when paused (a static monotonic 1e-323
    // curve). Without this, bars would lock at constant heights during
    // silence. We hash each frame; once we've seen the same hash for ~1.5s
    // we zero the input so smoothing decays everything to rest.
    property string lastBandsKey: ""
    property int stableFrameCount: 0
    readonly property int stableFramesForSilence: 45

    // Same perceptual amplifier music-wallpaper uses. cliamp's bands top
    // out around 0.4 on loud kicks; raw values read as "barely reacting".
    function shape(v) {
        return Math.pow(Math.min(1.0, v * 2.6), 0.72);
    }

    function parseColors(text) {
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (!m) continue;
            if (m[1] === "background") root.bgColor = m[2];
        }
    }

    FileView {
        id: paletteFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(paletteFile.text())
    }

    // ---------- cliamp visstream ----------
    Process {
        id: vis
        command: ["cliamp", "visstream", "--fps", "30"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (!line || line[0] !== "{") return;
                try {
                    const f = JSON.parse(line);
                    if (!f || !f.ok || !Array.isArray(f.bands) || f.bands.length === 0) return;

                    // Hash for stale-frame detection.
                    let key = "";
                    for (let i = 0; i < f.bands.length; i++)
                        key += f.bands[i].toFixed(5) + ",";
                    if (key === root.lastBandsKey) {
                        root.stableFrameCount++;
                    } else {
                        root.stableFrameCount = 0;
                        root.lastBandsKey = key;
                    }

                    if (root.stableFrameCount > root.stableFramesForSilence) {
                        const zeros = new Array(f.bands.length);
                        for (let i = 0; i < zeros.length; i++) zeros[i] = 0;
                        root.bands = zeros;
                    } else {
                        root.bands = f.bands;
                    }

                    // Lazy-init smoothing and peak arrays the first time
                    // we see a band count.
                    if (root.smoothBands.length !== f.bands.length) {
                        const n = f.bands.length;
                        const sb = new Array(n), pk = new Array(n), pv = new Array(n);
                        for (let i = 0; i < n; i++) { sb[i] = 0; pk[i] = 0; pv[i] = 0; }
                        root.smoothBands = sb;
                        root.peaks = pk;
                        root.peakVel = pv;
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running) restartTimer.start()
    }
    Timer {
        id: restartTimer
        interval: 3000; repeat: false
        onTriggered: vis.running = true
    }

    // ---------- 60fps tick: smoothing + peak fall ----------
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            const n = root.bands.length;
            if (!n || root.smoothBands.length !== n) {
                if (canvas.available) canvas.requestPaint();
                return;
            }

            const sb = root.smoothBands;
            const pk = root.peaks;
            const pv = root.peakVel;

            for (let i = 0; i < n; i++) {
                // Asymmetric smoothing: fast attack, slow release. Gives
                // the bars a snappy rise on transients and a "spring back"
                // settle the eye reads as musical.
                const t = root.shape(root.bands[i] || 0);
                const p = sb[i];
                sb[i] = t > p ? p + (t - p) * 0.55 : p + (t - p) * 0.18;

                // Peak hold: if the bar just outran the peak, snap the
                // peak up and reset its fall velocity to zero. Otherwise
                // accelerate the peak downward (gravity = 0.0012/frame^2)
                // so it lingers briefly at the top before plunging.
                if (sb[i] > pk[i]) {
                    pk[i] = sb[i];
                    pv[i] = 0;
                } else {
                    pv[i] += 0.0012;
                    pk[i] -= pv[i];
                    if (pk[i] < sb[i]) pk[i] = sb[i];
                    if (pk[i] < 0) pk[i] = 0;
                }
            }

            if (canvas.available) canvas.requestPaint();
        }
    }

    // ---------- Wallpaper surface ----------
    PanelWindow {
        id: wp
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "winamp-background"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        // Solid black-ish base. Winamp's spectrum sat in its own opaque
        // black skin window — we mimic that on the desktop layer.
        Rectangle {
            anchors.fill: parent
            color: Qt.darker(root.bgColor, 1.25)
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            antialiasing: false
            smooth: false

            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);

                const sb = root.smoothBands;
                const pk = root.peaks;
                const n = sb.length;
                if (!n) return;

                // Layout: bars span the full width, 28 segments tall,
                // centered vertically so there's quiet space above and
                // below. Bar width and gap derived from screen width.
                const barTotalW = w / n;
                const gap = Math.max(1, Math.floor(barTotalW * 0.18));
                const barW = Math.max(2, Math.floor(barTotalW - gap));

                // Reserve a margin top/bottom — the visualiser is centred
                // in the screen with breathing room rather than slammed
                // against the edges.
                const marginTop = h * 0.10;
                const marginBot = h * 0.10;
                const drawH = h - marginTop - marginBot;
                const segH = drawH / root.segments;
                const segGap = Math.max(1, Math.floor(segH * 0.18));
                const segDrawH = Math.max(2, segH - segGap);

                // Colour-zone thresholds inside the bar:
                //   bottom 60%  : green
                //   next 30%    : yellow
                //   top 10%     : red
                const greenTop = Math.floor(root.segments * 0.60);
                const yellowTop = Math.floor(root.segments * 0.90);

                const baseY = marginTop + drawH;  // y of the bottom of the lowest segment

                for (let i = 0; i < n; i++) {
                    const x = Math.floor(i * barTotalW + gap * 0.5);
                    const lit = Math.round(sb[i] * root.segments);

                    // Draw segments bottom-up. Lit segments are full
                    // colour; unlit segments are a very dim version of
                    // their zone colour so the whole grid is faintly
                    // visible at rest — that's a key part of Winamp's
                    // signature look.
                    for (let s = 0; s < root.segments; s++) {
                        const segY = baseY - (s + 1) * segH;
                        let c;
                        if (s < greenTop)        c = root.cGreen;
                        else if (s < yellowTop)  c = root.cYellow;
                        else                     c = root.cRed;

                        if (s < lit) {
                            ctx.fillStyle = c;
                        } else {
                            // Off-state: very faint zone colour so the
                            // matrix grid stays visible during silence.
                            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.07);
                        }
                        ctx.fillRect(x, segY, barW, segDrawH);
                    }

                    // Peak marker — a single segment-sized block riding
                    // on top of the bar. Drawn as a tiny offset rect so
                    // it visually detaches from the column below.
                    const peakSegFloat = pk[i] * root.segments;
                    if (peakSegFloat > 0.05) {
                        const peakSeg = Math.min(root.segments - 1, Math.floor(peakSegFloat));
                        const py = baseY - (peakSeg + 1) * segH;
                        ctx.fillStyle = root.cPeak;
                        ctx.fillRect(x, py, barW, Math.max(2, Math.floor(segDrawH * 0.55)));
                    }
                }
            }
        }

        // Subtle vignette so the bars feel inset rather than tiled across
        // the whole frame. Soft top/bottom only — sides stay clean to
        // preserve the LED-matrix grid edge.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 0.18; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }
    }
}
