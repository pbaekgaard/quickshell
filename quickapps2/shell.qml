import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Hexagonal quick-app launcher. Packed honeycomb cluster of hex tiles with a
// faint hex-grid background. Tab/arrow cycles through tiles, readout below.
ShellRoot {
    id: root

    // ---------- Apps ----------
    property var apps: []
    property int selectedIndex: 0
    readonly property var selectedApp: apps.length ? apps[selectedIndex] : null

    // ---------- Theme paths ----------
    readonly property string colorsPath:    Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.config/omarchy/current/theme.name"

    // ---------- Semantic palette ----------
    property color paper:   "#0c1014"
    property color ink:     "#cdd6f4"
    property color sumi:    "#7f849c"
    property color indigo:  "#89b4fa"
    property color seal:    "#f38ba8"

    readonly property color wash: Qt.lighter(paper, 1.15)

    // ---------- Hex geometry ----------
    // Tile is a pointy-top hexagon. Circumradius drives width/height.
    readonly property real tileR: 46
    readonly property real tileW: Math.sqrt(3) * tileR
    readonly property real tileH: 2 * tileR

    // Hex-ring radius. Scales with app count so the perimeter has enough
    // arclength to keep tiles from crowding each other. 90 is the minimum
    // centre-to-centre spacing we want; hex perimeter = 6 * R, so we solve
    // for R that gives spacing >= 90.
    readonly property real ringR: Math.max(230, apps.length * 90 / 6)

    // Place tile `index` of `total` evenly along the perimeter of a regular
    // pointy-top hexagon of radius `ringR`. First tile lands on the top
    // vertex (angle -90 deg), and subsequent tiles walk clockwise side-by-
    // side, interpolating linearly between corners. For total = 6 we get a
    // pure vertex placement; total = 12 gives corners + edge midpoints;
    // arbitrary counts spread evenly along the hex outline.
    function tileOffset(index, total) {
        if (total <= 0) return { x: 0, y: 0 };
        const t = (index / total) * 6;            // position in [0, 6)
        const side = Math.floor(t) % 6;
        const frac = t - Math.floor(t);
        const a1 = (-90 + 60 * side)       * Math.PI / 180;
        const a2 = (-90 + 60 * (side + 1)) * Math.PI / 180;
        const r = ringR;
        const x1 = r * Math.cos(a1), y1 = r * Math.sin(a1);
        const x2 = r * Math.cos(a2), y2 = r * Math.sin(a2);
        return { x: x1 + (x2 - x1) * frac, y: y1 + (y2 - y1) * frac };
    }

    // ---------- Navigation ----------
    function rotate(d) { if (apps.length) selectedIndex = (selectedIndex + d + apps.length) % apps.length; }
    function jumpTo(i) { if (apps.length) selectedIndex = Math.max(0, Math.min(apps.length - 1, i)); }

    // ---------- App list source ----------
    Process {
        running: true
        command: ["bash","-c",
            "cat \"$HOME/.config/omarchy-quickapps2/apps.json\" 2>/dev/null"
            + " || cat \"$HOME/.config/omarchy-quickapps/apps.json\" 2>/dev/null"
            + " || cat \""+Quickshell.shellDir+"/quickapps.example.json\""]
        stdout: StdioCollector {
            onStreamFinished: { try { root.apps = (JSON.parse(this.text).apps) || []; } catch(e) { console.warn(e); } }
        }
    }

    // ---------- Launcher ----------
    Process { id: launchProc; running: false; onExited: Qt.quit() }
    function launchSelected() {
        const a = selectedApp; if (!a) return;
        launchProc.command = ["sh","-c","setsid -f " + a.exec + " >/dev/null 2>&1"];
        launchProc.running = true;
    }

    // ---------- Palette watcher ----------
    function parseColors(text) {
        const want = { background: null, foreground: null, accent: null, color1: null, color8: null };
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (m && (m[1] in want)) want[m[1]] = m[2];
        }
        if (want.background) root.paper  = want.background;
        if (want.foreground) root.ink    = want.foreground;
        if (want.color8)     root.sumi   = want.color8;
        if (want.accent)     root.indigo = want.accent;
        if (want.color1)     root.seal   = want.color1;
    }

    FileView {
        id: paletteFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(paletteFile.text())
    }

    // theme.name has a stable inode across omarchy-theme-set, so it survives
    // the swap and we use it as a beacon to force-reload the palette file.
    FileView {
        id: themeMarker
        path: root.themeNamePath
        watchChanges: true
        onFileChanged: { reload(); paletteFile.reload(); }
    }

    PanelWindow {
        id: panel
        anchors { top: true; bottom: true; left: true; right: true }
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.97)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "omarchy-quickapps2"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Qt.quit()
            onWheel: (w) => {
                if (w.angleDelta.y > 0) root.rotate(-1);
                else if (w.angleDelta.y < 0) root.rotate(+1);
                w.accepted = true;
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q) { Qt.quit(); e.accepted = true; }
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H || e.key === Qt.Key_Up || e.key === Qt.Key_K
                       || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) { root.rotate(-1); e.accepted = true; }
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Down || e.key === Qt.Key_J
                       || e.key === Qt.Key_Tab) { root.rotate(+1); e.accepted = true; }
                else if (e.key === Qt.Key_Home) { root.jumpTo(0); e.accepted = true; }
                else if (e.key === Qt.Key_End)  { root.jumpTo(root.apps.length - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { root.launchSelected(); e.accepted = true; }
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                    const i = e.key - Qt.Key_1;
                    if (i < root.apps.length) { root.selectedIndex = i; root.launchSelected(); }
                    e.accepted = true;
                }
            }
        }

        // ---------- Faint hex grid background ----------
        Canvas {
            id: gridWash
            anchors.fill: parent
            opacity: 0.06
            property color stroke: root.indigo
            onStrokeChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = stroke;
                ctx.lineWidth = 1;
                const r = 38;
                const w = Math.sqrt(3) * r;
                const h = 2 * r;
                const vstep = h * 0.75;
                for (let row = -1; row * vstep < height + h; row++) {
                    const y = row * vstep;
                    const xoff = (row % 2 === 0) ? 0 : w / 2;
                    for (let col = -1; col * w + xoff < width + w; col++) {
                        const cx = col * w + xoff;
                        const cy = y;
                        ctx.beginPath();
                        for (let i = 0; i < 6; i++) {
                            const a = (Math.PI / 3) * i - Math.PI / 2;
                            const px = cx + r * Math.cos(a);
                            const py = cy + r * Math.sin(a);
                            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }
                        ctx.closePath();
                        ctx.stroke();
                    }
                }
            }
        }

        // ---------- Stage ----------
        Item {
            id: stage
            anchors.centerIn: parent
            width: 760; height: 760

            // Hex ring outline: a circle drawn from six line segments.
            // Tiles sit on the corners and edges of this outline.
            Canvas {
                id: hexRing
                anchors.fill: parent
                property color stroke: root.indigo
                property real radius: root.ringR
                onStrokeChanged: requestPaint()
                onRadiusChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.4;
                    ctx.lineWidth = 1;
                    const cx = width / 2, cy = height / 2;
                    ctx.beginPath();
                    for (let i = 0; i < 6; i++) {
                        const a = (-90 + 60 * i) * Math.PI / 180;
                        const px = cx + radius * Math.cos(a);
                        const py = cy + radius * Math.sin(a);
                        if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                    }
                    ctx.closePath();
                    ctx.stroke();
                }
            }

            // ---------- Hex tiles (hex-ring perimeter) ----------
            Repeater {
                model: root.apps
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool focused: index === root.selectedIndex
                    width: root.tileW + 6
                    height: root.tileH + 6

                    // Focused tile renders on top so the scale-up doesn't get
                    // clipped by a neighbour on a corner of the hex ring.
                    z: focused ? 10 : 1

                    // Position along the hex perimeter. apps.length is read so
                    // QML re-binds when the roster grows or shrinks.
                    readonly property var off: root.tileOffset(index, root.apps.length)
                    x: stage.width/2  - width/2  + off.x
                    y: stage.height/2 - height/2 + off.y
                    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }
                    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }

                    scale: focused ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuart } }

                    // Hex body
                    Canvas {
                        id: hexBody
                        anchors.fill: parent
                        property color fillColor: tile.focused ? root.ink : root.wash
                        property color strokeColor: tile.focused ? root.ink : Qt.rgba(root.indigo.r, root.indigo.g, root.indigo.b, 0.65)
                        property real strokeWidth: tile.focused ? 1.6 : 1.0
                        onFillColorChanged: requestPaint()
                        onStrokeColorChanged: requestPaint()
                        onStrokeWidthChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const cx = width / 2, cy = height / 2;
                            const r = root.tileR;
                            ctx.beginPath();
                            for (let i = 0; i < 6; i++) {
                                const a = (Math.PI / 3) * i - Math.PI / 2;
                                const px = cx + r * Math.cos(a);
                                const py = cy + r * Math.sin(a);
                                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                            }
                            ctx.closePath();
                            ctx.fillStyle = fillColor;
                            ctx.fill();
                            ctx.strokeStyle = strokeColor;
                            ctx.lineWidth = strokeWidth;
                            ctx.stroke();
                        }
                    }

                    Image {
                        id: iconImg
                        anchors.centerIn: parent
                        width: 38; height: 38
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        smooth: true; asynchronous: true; fillMode: Image.PreserveAspectFit
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: iconImg
                        source: iconImg
                        visible: iconImg.status === Image.Ready
                        colorization: 1.0
                        colorizationColor: tile.focused ? root.paper : root.ink
                        opacity: tile.focused ? 0.95 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }

                    // Fallback monogram if no icon resolved
                    Text {
                        anchors.centerIn: parent
                        visible: iconImg.status !== Image.Ready
                        text: (modelData.name || "?").charAt(0).toUpperCase()
                        color: tile.focused ? root.paper : root.ink
                        font.family: "monospace"; font.pixelSize: 22; font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = tile.index
                        onClicked: { root.selectedIndex = tile.index; root.launchSelected(); }
                    }
                }
            }

            // Centre readout sits in the empty middle of the hex ring.
            Column {
                anchors.centerIn: parent
                width: 360
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.selectedApp ? root.selectedApp.name.toUpperCase() : "----"
                    color: root.ink
                    font.family: "monospace"; font.pixelSize: 18; font.letterSpacing: 2; font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.selectedApp ? (root.selectedApp.comment || root.selectedApp.exec || "") : ""
                    color: root.sumi
                    font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1
                }
            }
        }

        // ---------- Footer hint ----------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            text: "TAB  CYCLE     ENT  EXECUTE     ESC  DISMISS"
            color: root.sumi
            font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 3
        }
    }
}
