import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Ten subtle fluid-shader backgrounds. Sits on the Wayland Background
// layer (so it replaces omarchy's wallpaper while running) and cycles
// through one shader per ~90 s with a long cross-fade. Colours are
// pulled live from the omarchy palette, so every theme swap re-tints
// the active background without restart.
//
// IPC:
//   qs -c backgrounds ipc call bg next
//   qs -c backgrounds ipc call bg pick 0..9
//   qs -c backgrounds ipc call bg hold      # pause auto-cycle
//   qs -c backgrounds ipc call bg cycle     # resume auto-cycle
//   qs -c backgrounds ipc call bg reload    # re-read palette
ShellRoot {
    id: root

    // ---------- Theme ----------
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.config/omarchy/current/theme.name"

    property color paper:  "#181616"
    property color ink:    "#c5c9c5"
    property color accent: "#5d799b"
    property color seal:   "#c4746e"

    // ---------- Cycle state ----------
    property int  bgIndex: 0
    property bool autoCycle: true

    readonly property var bgList: [
        "shaders/drift.frag.qsb",
        "shaders/veil.frag.qsb",
        "shaders/mist.frag.qsb",
        "shaders/ripple.frag.qsb",
        "shaders/silk.frag.qsb",
        "shaders/caustics.frag.qsb",
        "shaders/breath.frag.qsb",
        "shaders/smoke.frag.qsb",
        "shaders/dunes.frag.qsb",
        "shaders/aurora.frag.qsb",
        "shaders/orbs.frag.qsb"
    ]
    readonly property int bgCount: bgList.length

    // Long dwell + long fade so the eye doesn't notice the change.
    readonly property real dwellSec: 90.0
    readonly property real fadeMs:   4000

    function parseColors(text) {
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (!m) continue;
            const k = m[1], v = m[2];
            if (k === "background")      root.paper  = v;
            else if (k === "foreground") root.ink    = v;
            else if (k === "color4")     root.accent = v;
            else if (k === "color1")     root.seal   = v;
            else if (k === "accent")     root.accent = v;
        }
    }

    FileView {
        id: paletteFile
        path: root.colorsPath
        onLoaded: root.parseColors(paletteFile.text())
    }
    // theme.name marker is what omarchy actually updates atomically;
    // file-watching the colours.toml itself races omarchy's rm+mv.
    FileView {
        id: themeMarker
        path: root.themeNamePath
        watchChanges: true
        onFileChanged: { reload(); paletteFile.reload(); }
    }
    Component.onCompleted: paletteFile.reload()

    IpcHandler {
        target: "bg"
        function next():  void {
            root.bgIndex = (root.bgIndex + 1) % root.bgCount;
            wp.dwell = 0;
        }
        function prev():  void {
            root.bgIndex = (root.bgIndex - 1 + root.bgCount) % root.bgCount;
            wp.dwell = 0;
        }
        function pick(i: int): void {
            const n = ((i % root.bgCount) + root.bgCount) % root.bgCount;
            root.bgIndex = n;
            wp.dwell = 0;
        }
        function hold():   void { root.autoCycle = false; }
        function cycle():  void { root.autoCycle = true;  }
        function toggle(): void { root.autoCycle = !root.autoCycle; }
        function reload(): void { paletteFile.reload(); }
    }

    PanelWindow {
        id: wp
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "backgrounds"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}   // fully click-through

        // Continuous animation clock — never resets so the slow
        // shaders don't visibly hitch when bgIndex changes.
        property real elapsed: 0
        // Seconds the current shader has been on top. Reset on bgIndex
        // change so manual picks restart the dwell window.
        property real dwell: 0

        Timer {
            interval: 16
            repeat: true
            running: true
            onTriggered: {
                wp.elapsed += 0.016;
                wp.dwell   += 0.016;
                if (root.autoCycle && wp.dwell >= root.dwellSec) {
                    wp.dwell = 0;
                    root.bgIndex = (root.bgIndex + 1) % root.bgCount;
                }
            }
        }

        // Solid paper base so every shader has a guaranteed backdrop
        // during cross-fade gaps and at first paint.
        Rectangle {
            anchors.fill: parent
            color: root.paper
        }

        // Shader stack. Same pattern as the screensaver: every entry
        // gets one ShaderEffect, opacity-faded between them.
        Item {
            id: stack
            anchors.fill: parent

            Repeater {
                model: root.bgList
                delegate: ShaderEffect {
                    required property int index
                    required property string modelData
                    anchors.fill: parent
                    opacity: root.bgIndex === index ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutSine } }
                    property real  iTime: wp.elapsed
                    property size  iResolution: Qt.size(width, height)
                    property color colPaper:  root.paper
                    property color colInk:    root.ink
                    property color colAccent: root.accent
                    property color colSeal:   root.seal
                    fragmentShader: modelData
                }
            }
        }
    }
}
