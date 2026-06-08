import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Kanji-rain music wallpaper. Vertical columns of music-themed kanji
// fall continuously down the screen across three depth tiers (far/mid/
// near) so the motion has parallax. The head glyph at the leading edge
// of each column is brightest; the tail fades upward.
//
// On each bass transient a horizontal flash-line sweeps from top to
// bottom over ~620 ms. Glyphs within its passing band flash hot-white,
// then settle back to the accent tint. Several sweeps can be in flight
// at once so fast beats stack into overlapping waves.
ShellRoot {
    id: root

    // ---------- Theme ----------
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    property color accent: "#c4746e"
    property color bgColor: "#15151c"

    // ---------- Audio ----------
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var smoothBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real bass: 0
    property real mids: 0
    property real highs: 0
    property real energy: 0

    // Bass-transient detector (adaptive baseline)
    property real bassEnv: 0
    property real bassPrev: 0
    property real lastBeatMs: 0

    // Global beat-pulse — punched to 1.0 on each transient, decays to 0
    // over ~280ms. Every glyph mixes this into its brightness so each
    // detected kick visibly washes the whole screen.
    property real beatPulse: 0

    // ---------- Beat sweeps ----------
    // Active flash-lines. Each entry: { startMs }.
    // Pruned each tick once age > sweepDurationMs.
    property var sweeps: []
    readonly property real sweepDurationMs: 520
    readonly property real sweepHalfBand: 56   // px above/below the line that still flashes

    // Continuous "ambient" scan line that's always travelling top-to-
    // bottom on a slow loop, independent of beats. Visibility scales
    // with overall energy so it dims to nothing during silence.
    property real ambientSweepY: 0
    readonly property real ambientSweepHalfBand: 70

    // ---------- Stale-frame silence detection ----------
    // cliamp emits a frozen frame when paused (or when its visualizer
    // isn't connected to live audio). The values aren't zero — they
    // sit at a static monotonic curve that would otherwise drive the
    // wallpaper at constant full brightness. We hash each incoming
    // band line and zero out the data once we've seen the same hash
    // for ~1.5s.
    property string lastBandsKey: ""
    property int stableFrameCount: 0
    readonly property int stableFramesForSilence: 45  // ~1.5s at 30fps

    // ---------- Beat bursts ----------
    // Each entry: { x, y, glyph, fontSize, age, life }.
    // Spawned on every detected bass transient as a per-beat stamp.
    property var bursts: []

    // ---------- Columns ----------
    property var columns: []
    property bool columnsBuilt: false

    // Music / sound / weather kanji pool. Mixing musical glyphs with a
    // few naturescape ones keeps the rain from looking like an EQ readout.
    readonly property var glyphPool: [
        "音","響","鼓","拍","律","韻","唄","楽","奏","振",
        "鳴","歌","調","曲","節","声","詩","舞","踊","吟",
        "笛","琴","弦","詠","聴","聞","旋","波","心","風",
        "光","影","夜","夢","霧","月","花","雨","雪","川",
        "静","流","空","海","龍","雷","炎","刃","禅","道"
    ]

    function randRange(lo, hi) { return lo + Math.random() * (hi - lo); }
    function pickGlyph() { return root.glyphPool[Math.floor(Math.random() * root.glyphPool.length)]; }

    // Perceptual amplifier for cliamp's raw band values. cliamp's bands
    // top out around 0.4 even on loud kicks, so feeding them directly to
    // visual amplitude reads as "barely reacting". 2.6x linear gain
    // followed by a pow(_, 0.72) curve lifts mid-loud values toward 1.0
    // while leaving silence as silence, and the soft clamp keeps peaks
    // pinned at 1.0 without blowing up.
    function shape(v) {
        return Math.pow(Math.min(1.0, v * 2.6), 0.72);
    }

    function parseColors(text) {
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (!m) continue;
            if (m[1] === "color1")          root.accent  = m[2];
            else if (m[1] === "background") root.bgColor = m[2];
        }
    }

    // Build the column set once we know canvas dimensions. Three tiers
    // give parallax: far = small/slow/dim, mid = medium, near = big/fast/bright.
    function buildColumns(W, H) {
        const cols = [];
        const tiers = [
            { count: Math.max(8, Math.round(W / 75)),  fontSize: 13, speedLo: 35,  speedHi: 60,  alpha: 0.32, tailLen: 13 },
            { count: Math.max(8, Math.round(W / 65)),  fontSize: 19, speedLo: 70,  speedHi: 105, alpha: 0.62, tailLen: 17 },
            { count: Math.max(4, Math.round(W / 110)), fontSize: 28, speedLo: 105, speedHi: 160, alpha: 0.95, tailLen: 22 },
        ];
        for (let ti = 0; ti < tiers.length; ti++) {
            const tier = tiers[ti];
            for (let i = 0; i < tier.count; i++) {
                const tailLen = tier.tailLen + Math.floor(randRange(0, 5));
                const fontSize = tier.fontSize + Math.floor(randRange(-1, 3));
                const spacing = fontSize * 1.05;
                const glyphs = new Array(tailLen);
                for (let g = 0; g < tailLen; g++) glyphs[g] = pickGlyph();
                const cx = randRange(0, W);
                cols.push({
                    x: cx,
                    // Stagger initial headY across full vertical range plus an
                    // offset above the top so columns are visibly desynced.
                    headY: randRange(-H * 0.5, H),
                    speed: randRange(tier.speedLo, tier.speedHi),
                    fontSize: fontSize,
                    spacing: spacing,
                    tailLen: tailLen,
                    alpha: tier.alpha,
                    glyphs: glyphs,
                    scrambleCooldown: randRange(20, 80),  // frames until next scramble
                    fontStr: "bold " + fontSize + "px \"Noto Sans CJK JP\", sans-serif",
                    // Each column is bound to one frequency band, indexed
                    // by its x position. The screen reads bass-on-left to
                    // highs-on-right, so the whole spectrum is visible at
                    // a glance instead of mids/highs going to waste.
                    bandIndex: Math.max(0, Math.min(6, Math.floor((cx / W) * 7))),
                });
            }
        }
        return cols;
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
                    // Cheap hash: rounded join. Float jitter from the same
                    // underlying state still hashes identical at 4 decimals,
                    // so paused streams with identical floats collapse.
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
                        // Treat as silence: feed zeros so the smoother
                        // decays the visuals naturally to rest state.
                        const zeros = new Array(f.bands.length);
                        for (let i = 0; i < zeros.length; i++) zeros[i] = 0;
                        root.bands = zeros;
                    } else {
                        root.bands = f.bands;
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

    // ---------- 60 fps tick ----------
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            // Band smoothing (attack 0.45, release 0.10). cliamp emits
            // 10 bands but the top three (7-9) sit at the FP noise floor
            // for almost all music — they're well above 12 kHz where
            // there's practically no energy. We still smooth all bands
            // for completeness, but the aggregates only consider 0..6.
            const n = root.bands.length;
            if (n) {
                const prev = root.smoothBands;
                const out = new Array(n);
                const lastUsable = Math.min(n, 7);
                const splitMidLo = 2;   // bass = bands 0..1
                const splitMidHi = 5;   // mids = bands 2..4, highs = bands 5..6
                let lo = 0, mi = 0, hi = 0, sum = 0;
                for (let i = 0; i < n; i++) {
                    const t = root.bands[i] || 0;
                    const p = prev[i] || 0;
                    const nxt = t > p ? p + (t - p) * 0.45 : p + (t - p) * 0.10;
                    out[i] = nxt;
                    if (i < lastUsable) {
                        sum += nxt;
                        if (i < splitMidLo)      lo += nxt;
                        else if (i < splitMidHi) mi += nxt;
                        else                     hi += nxt;
                    }
                }
                root.smoothBands = out;
                root.energy = shape(sum / lastUsable);
                root.bass   = shape(lo / splitMidLo);
                root.mids   = shape(mi / (splitMidHi - splitMidLo));
                root.highs  = shape(hi / (lastUsable - splitMidHi));
            }

            // Bass-transient detector (adaptive baseline). Threshold is
            // the max of an absolute floor and 1.35x the slow envelope —
            // works in both quiet and loud passages. Rise gate accepts
            // either +0.08 absolute jump OR 22% relative jump, so faint
            // kicks during quiet sections still register.
            root.bassEnv = root.bassEnv * 0.985 + root.bass * 0.015;
            const now = Date.now();
            const threshold = Math.max(0.42, root.bassEnv * 1.35);
            if (root.bass > threshold
                && (root.bass > root.bassPrev + 0.08
                    || root.bass > root.bassPrev * 1.22)
                && now - root.lastBeatMs > 150) {
                root.lastBeatMs = now;
                root.beatPulse = 1.0;
                root.sweeps.push({ startMs: now });
                // Cap concurrent sweeps so frantic tracks stay readable.
                while (root.sweeps.length > 6) root.sweeps.shift();

                // Spawn a beat-burst kanji stamp. Each beat gets its own
                // randomly-placed character that pops in fast and fades
                // over ~800ms. Position is biased toward the screen
                // center so the rain doesn't get cluttered at the edges.
                const W = canvas.width || 1, H = canvas.height || 1;
                const bx = W * 0.5 + (Math.random() - 0.5) * W * 0.62;
                const by = H * (0.18 + Math.random() * 0.50);
                root.bursts.push({
                    x: bx,
                    y: by,
                    glyph: pickGlyph(),
                    fontSize: 70 + Math.floor(root.bass * 70),
                    age: 0,
                    life: 780 + Math.random() * 220,
                });
                while (root.bursts.length > 5) root.bursts.shift();
            }
            root.bassPrev = root.bass;

            // Decay the global beat pulse (~280ms to zero from 1.0).
            root.beatPulse = Math.max(0, root.beatPulse - 0.057);

            // Advance and prune beat bursts.
            const blist = root.bursts;
            let bw = 0;
            for (let bi = 0; bi < blist.length; bi++) {
                blist[bi].age += 16;
                if (blist[bi].age < blist[bi].life) blist[bw++] = blist[bi];
            }
            blist.length = bw;

            // Lazy-build columns once canvas has size
            if (!root.columnsBuilt && canvas.width > 0 && canvas.height > 0) {
                root.columns = root.buildColumns(canvas.width, canvas.height);
                root.columnsBuilt = true;
            }

            // Advance columns. Global speed = energy + beat-pulse shove.
            // Per-column = also gets a kick from its bound band's level,
            // so a bass-bound column on the left speeds up on low-end
            // hits while a highs-bound column on the right speeds up on
            // cymbals — same screen, different parts moving on different
            // parts of the spectrum.
            const globalSpeed = 1.0 + root.energy * 0.80 + root.beatPulse * 0.55;
            const H = canvas.height || 1;
            const W = canvas.width || 1;
            const cols = root.columns;
            for (let c = 0; c < cols.length; c++) {
                const col = cols[c];
                const bandRaw = root.smoothBands[col.bandIndex] || 0;
                const bandLevel = shape(bandRaw);  // 0..1 after gain curve

                col.headY += col.speed * (globalSpeed + bandLevel * 0.90) * 0.016;

                // Reset when the entire tail has fallen below the bottom.
                const tailTopY = col.headY - col.tailLen * col.spacing;
                if (tailTopY > H + col.spacing) {
                    col.headY = -randRange(col.spacing * 2, col.spacing * 8);
                    // Reshuffle a chunk of glyphs so the reborn column feels fresh.
                    for (let g = 0; g < col.glyphs.length; g++)
                        if (Math.random() < 0.55) col.glyphs[g] = pickGlyph();
                    col.x = randRange(0, W);
                    // x changed -> rebind to a new band so the spectrum
                    // map stays consistent across resets.
                    col.bandIndex = Math.max(0, Math.min(6, Math.floor((col.x / W) * 7)));
                }

                // Scramble rate accelerates with mids (vocals/melody) and
                // with this column's own band. Loud melodic sections make
                // the rain visibly busier; quiet sections settle down.
                col.scrambleCooldown -= 1 + root.mids * 2.5 + bandLevel * 2.0;
                if (col.scrambleCooldown <= 0) {
                    const idx = Math.floor(Math.random() * col.glyphs.length);
                    col.glyphs[idx] = pickGlyph();
                    col.scrambleCooldown = randRange(15, 70);
                }
            }

            // Continuous ambient sweep — always travelling top-to-bottom
            // on a ~4.2s loop so something is visibly moving even between
            // kicks. The y wraps past the bottom edge with extra slack so
            // the band fades out off-screen before reappearing at the top.
            root.ambientSweepY = (root.ambientSweepY + (H * 0.004)) % (H + 200);

            // Prune expired sweeps in place
            const sw = root.sweeps;
            let w = 0;
            for (let s = 0; s < sw.length; s++) {
                if (now - sw[s].startMs <= root.sweepDurationMs) {
                    sw[w++] = sw[s];
                }
            }
            sw.length = w;

            if (canvas.available) canvas.requestPaint();
        }
    }

    // ---------- Wallpaper surface ----------
    PanelWindow {
        id: wp
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "music-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        // Background gradient — slightly cooler at the top, deeper bg at
        // bottom. The kanji glyphs sit on top of this.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(root.bgColor, 1.10) }
                GradientStop { position: 1.0; color: Qt.darker(root.bgColor, 1.45) }
            }
        }

        // Subtle accent wash that lifts with overall energy.
        Rectangle {
            anchors.fill: parent
            color: root.accent
            opacity: 0.03 + root.energy * 0.08
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            antialiasing: true
            smooth: true

            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);

                ctx.textAlign = "center";
                ctx.textBaseline = "middle";

                const ar = root.accent.r, ag = root.accent.g, ab = root.accent.b;
                const now = Date.now();

                // Resolve active sweep positions once per paint
                const sw = root.sweeps;
                const sweepCount = sw.length;
                const sweepYs = new Array(sweepCount);
                const sweepStrengths = new Array(sweepCount);
                for (let s = 0; s < sweepCount; s++) {
                    const tt = (now - sw[s].startMs) / root.sweepDurationMs;
                    sweepYs[s] = tt * h;
                    // Strength ramps in fast, holds, fades out
                    sweepStrengths[s] = tt < 0.10 ? tt * 10
                                      : tt > 0.80 ? Math.max(0, 1 - (tt - 0.80) / 0.20)
                                      : 1.0;
                }

                // ----- Columns -----
                const cols = root.columns;
                const baseBoost = 0.85 + root.energy * 0.50 + root.beatPulse * 0.25;
                const pulseHot = root.beatPulse * 0.22;
                const ambY = root.ambientSweepY;
                const ambHalf = root.ambientSweepHalfBand;
                // Ambient sweep visibility scales purely with energy now —
                // no constant baseline. During silence it vanishes.
                const ambStrength = root.energy * 0.75;
                const sparkleProb = root.highs * 0.0045;  // muted from 0.012

                // Hot-accent target — a lightened version of the theme
                // accent. Glyphs that "brighten" now mix toward this hue
                // family instead of pure white, so they stay on-palette.
                const lr = Math.min(1, ar * 1.30 + 0.15);
                const lg = Math.min(1, ag * 1.30 + 0.15);
                const lb = Math.min(1, ab * 1.30 + 0.15);

                for (let c = 0; c < cols.length; c++) {
                    const col = cols[c];
                    ctx.font = col.fontStr;

                    // Per-column band level — drives this column's
                    // brightness, sparkle rate, and head intensity.
                    const bandRaw = root.smoothBands[col.bandIndex] || 0;
                    const bandLevel = shape(bandRaw);
                    const colBoost = baseBoost + bandLevel * 0.40;

                    for (let i = 0; i < col.tailLen; i++) {
                        const y = col.headY - (col.tailLen - 1 - i) * col.spacing;
                        if (y < -col.fontSize || y > h + col.fontSize) continue;

                        const tailT = i / (col.tailLen - 1);
                        const fade = Math.pow(tailT, 1.6);
                        const baseAlpha = col.alpha * fade;

                        const isHead     = i === col.tailLen - 1;
                        const isNearHead = i >= col.tailLen - 3;

                        // Sweep flash: max over all active sweeps near this y
                        let flash = 0;
                        for (let s = 0; s < sweepCount; s++) {
                            const dy = Math.abs(y - sweepYs[s]);
                            if (dy < root.sweepHalfBand) {
                                const f = (1 - dy / root.sweepHalfBand) * sweepStrengths[s];
                                if (f > flash) flash = f;
                            }
                        }

                        // Ambient sweep band — energy-gated, so silence
                        // makes it disappear entirely.
                        const ady = Math.abs(y - ambY);
                        if (ady < ambHalf) {
                            const af = (1 - ady / ambHalf) * ambStrength;
                            if (af > flash) flash = af;
                        }

                        // Sparkle: muted, accent-tinted (no pure white).
                        const sparkle = Math.random() < (sparkleProb + bandLevel * 0.002);
                        const sparkleMix = sparkle ? 0.55 : 0;

                        // Hot-mix toward lightened accent (not white):
                        //   - sweep band passing through this y
                        //   - ambient continuous sweep
                        //   - head-of-column boost
                        //   - global beat pulse
                        //   - random sparkles on highs
                        const headMix = isHead ? 0.40 : (isNearHead ? 0.14 : 0);
                        const hot = Math.min(1, flash + headMix + pulseHot + sparkleMix);

                        const fr = ar + (lr - ar) * hot;
                        const fg = ag + (lg - ag) * hot;
                        const fb = ab + (lb - ab) * hot;
                        const fa = Math.min(1, (baseAlpha + flash * 0.45 + pulseHot * 0.15 + sparkleMix * 0.20 + (isHead ? 0.20 : 0)) * colBoost);
                        if (fa < 0.04) continue;

                        ctx.fillStyle = Qt.rgba(fr, fg, fb, fa);
                        ctx.fillText(col.glyphs[i], col.x, y);
                    }
                }

                // ----- Beat-burst glyphs -----
                // Each detected kick stamps a big kanji at a random
                // position. It pops in fast (0..1 scale over 80ms),
                // holds briefly, then fades over the rest of its life.
                // Drawn in accent color (not white) so it reads as a
                // calligraphic stamp rather than a flash.
                const blist = root.bursts;
                for (let bi = 0; bi < blist.length; bi++) {
                    const b = blist[bi];
                    const t = b.age / b.life;
                    // Scale: 0..1 over the first 12% of life, then holds.
                    const scaleT = t < 0.12 ? t / 0.12 : 1;
                    const scale = 0.4 + 0.6 * (1 - Math.pow(1 - scaleT, 3));
                    // Alpha: rises with scale, decays from 35% onward.
                    const alphaRise = Math.min(1, t / 0.10);
                    const alphaFall = t > 0.35 ? Math.max(0, 1 - (t - 0.35) / 0.65) : 1;
                    const a = alphaRise * alphaFall * 0.88;
                    if (a < 0.02) continue;

                    ctx.font = "bold " + Math.round(b.fontSize * scale) + "px \"Noto Sans CJK JP\", sans-serif";
                    // Soft outer halo
                    ctx.fillStyle = Qt.rgba(lr, lg, lb, a * 0.20);
                    ctx.fillText(b.glyph, b.x, b.y);
                    // Solid centre — hot-accent, not white
                    ctx.fillStyle = Qt.rgba(lr, lg, lb, a);
                    ctx.fillText(b.glyph, b.x, b.y);
                }

                // Ambient sweep gradient band: removed. The sweep still
                // shows through the per-glyph flash mix (glyphs near
                // ambY get brightened above), so the effect remains on
                // the kanji themselves without painting an explicit band.

                // ----- Beat sweep core lines -----
                // Wide gradient band removed. Kept the thin sharp core
                // line so each kick has a visible scanline mark cutting
                // across the rain — the brightening of the surrounding
                // glyphs is handled in the column loop's `flash` term.
                for (let s = 0; s < sweepCount; s++) {
                    const yC = sweepYs[s];
                    const k = sweepStrengths[s];
                    if (k <= 0) continue;
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.28 * k);
                    ctx.fillRect(0, yC - 1, w, 2);
                }
            }
        }

        // Top and bottom vignette — frames the rain so the edges fade out
        // instead of cutting off abruptly.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 0.18; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.40) }
            }
        }
    }
}
