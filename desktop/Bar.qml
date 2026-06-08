import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var root

    color: "transparent"
    // Anchors track barEdge — three sides anchored, the side opposite
    // the bar's edge is left free for the bar's thickness to extend.
    anchors {
        top:    bar.root.barEdge !== "bottom"
        bottom: bar.root.barEdge !== "top"
        left:   bar.root.barEdge !== "right"
        right:  bar.root.barEdge !== "left"
    }
    // Cloud mode: horizontal+round only. Vertical bars keep the original
    // slab geometry to avoid breaking the proven layout.
    readonly property int cloudPad: 2
    readonly property int cloudAir: 5
    readonly property int cloudInnerAir: 2
    readonly property bool cloudMode: bar.root.round && bar.root.isHorizontal
    readonly property int extraThickness: cloudMode ? 2 * cloudPad + cloudAir + cloudInnerAir : 0
    // innerSign tells which side gets the extra outer air (away from screen).
    readonly property int innerSign: bar.root.barEdge === "top" ? 1 : (bar.root.barEdge === "bottom" ? -1 : 0)

    implicitHeight: bar.root.isHorizontal ? bar.root.barHeight + extraThickness : 0
    implicitWidth:  bar.root.isHorizontal ? 0 : bar.root.barHeight
    exclusiveZone:  bar.root.isHorizontal ? bar.root.barHeight + extraThickness : bar.root.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-menu"

    // Re-claim the popup anchors when this face becomes the visible one
    // (the sibling BarHacker registers its own items while it's up). Popups
    // read these at open time, so whoever is mapped must own them.
    onVisibleChanged: if (visible) {
        bar.root.calendarAnchorItem = clockItem;
        bar.root.weatherAnchorItem = weatherMod;
    }

    // In cloud mode the slab bg is replaced by a single rounded backdrop
    // sized to match the inner bar (barHeight tall, with cloudAir margins
    // on each side along the bar axis, sliding toward the inner edge so
    // outer-side air sits between cloud and screen edge).
    Rectangle {
        id: cloudBg
        visible: bar.cloudMode
        x: bar.cloudAir
        y: bar.innerSign === 1 ? bar.cloudAir : bar.cloudInnerAir
        width: parent.width - 2 * bar.cloudAir
        height: bar.root.barHeight + 2 * bar.cloudPad
        radius: bar.root.cornerRadius
        color: bar.root.bg
        z: 0
        // Idle dim, slow 6s ease both ways. Driven by states/transitions rather
        // than a Behavior with an isIdle-bound duration: that bound duration is
        // re-evaluated in the same notify pass as the opacity write and lags one
        // toggle behind, so each direction could inherit the other's speed.
        // from/to pins each direction's duration.
        opacity: 1.0
        states: State {
            name: "idle"
            when: bar.root.isIdle
            PropertyChanges { target: cloudBg; opacity: 0.7 }
        }
        transitions: [
            Transition {
                to: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuart }
            },
            Transition {
                from: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuad }
            }
        ]
    }

    // Container for clock + modules + hairlines. In cloud mode the bg
    // becomes transparent so the cloud rectangle above shows through;
    // in slab mode this acts as the bar background.
    Rectangle {
        id: slabBg
        anchors.fill: parent
        color: bar.cloudMode ? "transparent" : bar.root.bg
        // Slab-mode idle dim (cloud mode keeps this transparent + opaque; the
        // cloudBg rectangle above handles the dim there). Same states/transitions
        // approach as cloudBg, slow 6s ease in both directions.
        opacity: 1.0
        states: State {
            name: "idle"
            when: bar.root.isIdle && !bar.cloudMode
            PropertyChanges { target: slabBg; opacity: 0.7 }
        }
        transitions: [
            Transition {
                to: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuart }
            },
            Transition {
                from: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuad }
            }
        ]

        // Inner-edge hairline (facing the rest of the screen). Hidden in
        // cloud mode — the rounded backdrop replaces it visually.
        Rectangle {
            visible: !bar.cloudMode && bar.root.isHorizontal
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    bar.root.barEdge === "bottom" ? parent.top    : undefined
            anchors.bottom: bar.root.barEdge === "top"    ? parent.bottom : undefined
            height: 1
            color: bar.root.sep
        }
        Rectangle {
            visible: !bar.cloudMode && !bar.root.isHorizontal
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.right:  bar.root.barEdge === "left"  ? parent.right : undefined
            anchors.left:   bar.root.barEdge === "right" ? parent.left  : undefined
            width: 1
            color: bar.root.sep
        }

        // Centre cluster: clock only, clickable. Horizontal bars show
        // "HH:MM" on one line; vertical bars stack HH and MM.
        Item {
            id: clockItem
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 1
            anchors.verticalCenter:   parent.verticalCenter
            // In cloud mode the visual backdrop (cloudBg) is offset from
            // the bar's geometric centre.  Correct so the text stays
            // centred within the visible rounded backdrop.
            anchors.verticalCenterOffset: bar.cloudMode
                ? (bar.innerSign * (cloudAir - cloudInnerAir)) / 2
                : 0
            z: 10
            Component.onCompleted: bar.root.calendarAnchorItem = clockItem

            implicitWidth:  bar.root.isHorizontal
                            ? clockOneLine.implicitWidth + 14
                            : Math.max(clockHH.implicitWidth, clockMM.implicitWidth) + 8
            implicitHeight: bar.root.isHorizontal
                            ? clockOneLine.implicitHeight + 8
                            : (clockHH.implicitHeight + clockMM.implicitHeight + 6)

            Bloom { id: clockBloom; root: bar.root }

            Text {
                id: clockOneLine
                visible: bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter:   parent.verticalCenter
                text: bar.root.hh + ":" + bar.root.mm
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 12
                font.letterSpacing: 2
                font.weight: Font.Bold
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                id: clockHH
                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 1
                text: bar.root.hh
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
                font.weight: Font.Light
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                id: clockMM
                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 1
                text: bar.root.mm
                color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
                font.weight: Font.Light
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            Timer {
                id: clockTipDelay
                interval: 320
                onTriggered: {
                    const p = clockItem.mapToItem(null, clockItem.width / 2, clockItem.height / 2);
                    bar.root.showTooltip("Calendar", p.x, p.y);
                }
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { clockBloom.fire(mouseX, mouseY); clockTipDelay.restart(); }
                onExited:  { clockTipDelay.stop(); bar.root.hideTooltip("Calendar"); }
                onClicked: {
                    clockTipDelay.stop();
                    bar.root.hideTooltip("Calendar");
                    if (bar.root.calendarVisible) bar.root.calendarVisible = false;
                    else bar.root.openCalendar();
                }
            }
        }

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin:   bar.root.isHorizontal ? (bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10) : 0
            anchors.rightMargin:  bar.root.isHorizontal
                                  ? (bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10)
                                  : 0
            anchors.topMargin:    bar.root.isHorizontal
                                  ? (bar.cloudMode
                                     ? (bar.root.barEdge === "top" ? bar.cloudAir + bar.cloudPad : bar.cloudInnerAir + bar.cloudPad)
                                     : 0)
                                  : 10
            anchors.bottomMargin: bar.root.isHorizontal
                                  ? (bar.cloudMode
                                     ? (bar.root.barEdge === "top" ? bar.cloudInnerAir + bar.cloudPad : bar.cloudAir + bar.cloudPad)
                                     : 0)
                                  : 10
            flow: bar.root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rowSpacing: 4
            columnSpacing: 4
            columns: bar.root.isHorizontal ? -1 : 1
            rows:    bar.root.isHorizontal ? 1  : -1

            // Module {
            //     root: bar.root
            //     glyph: bar.root.icoOmarchy
            //     tooltip: "Menu"
            //     color: bar.root.seal
            //     fontFamily: "omarchy"
            //     fontSize: 14
            //     onActivated: bar.root.paletteToggleRequested()
            //     onRightActivated: bar.root.run("xdg-terminal-exec")
            // }
            //
            // Separator { root: bar.root }

            Repeater {
                model: 5
                delegate: Workspace {
                    required property int index
                    root: bar.root
                    wsId: index + 1
                    label: index + 1
                    active: bar.root.activeWs === (index + 1)
                    present: bar.root.existingWs.indexOf(index + 1) !== -1
                    onActivated: bar.root.run("hyprctl dispatch workspace " + (index + 1))
                }
            }

            Separator { root: bar.root }

            // Now-playing pill, to the right of workspace indicators.
            Item {
                id: musicItem
                readonly property bool present: bar.root.isHorizontal && bar.root.musicTitle.length > 0
                readonly property string displayTitle: {
                    if (bar.root.musicArtist.length > 0) return bar.root.musicTitle;
                    var idx = bar.root.musicTitle.lastIndexOf(" - ");
                    return idx > 0 ? bar.root.musicTitle.substring(0, idx) : bar.root.musicTitle;
                }
                readonly property string displayArtist: {
                    if (bar.root.musicArtist.length > 0) return bar.root.musicArtist;
                    var idx = bar.root.musicTitle.lastIndexOf(" - ");
                    return idx > 0 ? bar.root.musicTitle.substring(idx + 3) : "";
                }
                readonly property real contentW: Math.max(titleText.implicitWidth, artistText.implicitWidth) + 15 + musicIcon.implicitWidth
                readonly property real maxPillWidth: 200
                property real openW: present ? Math.min(contentW + 8, maxPillWidth) : 0
                Behavior on openW { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                visible: present || openW > 0.5
                Layout.preferredWidth: openW
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 8
                height: 16
                width: openW
                z: 10

                readonly property string tipText: musicItem.displayArtist.length > 0
                                                  ? musicItem.displayTitle + " - " + musicItem.displayArtist
                                                  : musicItem.displayTitle

                Rectangle {
                    id: musicPill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width)
                    height: parent.height
                    radius: height / 2
                    color: bar.root.accent
                    clip: true
                    opacity: musicMouse.containsMouse ? 1.0 : 0.9
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Item {
                        id: textClip
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 5 + musicIcon.implicitWidth + 5
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        height: parent.height
                        clip: true

                        readonly property bool hasArtist: musicItem.displayArtist.length > 0
                        property bool showTitle: true
                        property real slideY: 0

                        NumberAnimation {
                            id: slideAnim
                            target: textClip
                            property: "slideY"
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }

                        Timer {
                            interval: 3500
                            running: textClip.hasArtist
                            repeat: true
                            onTriggered: {
                                textClip.showTitle = !textClip.showTitle;
                                slideAnim.to = textClip.showTitle ? 0 : -16;
                                slideAnim.start();
                            }
                        }

                        Item {
                            x: 0
                            y: textClip.slideY
                            width: textClip.width
                            height: 16
                            Text {
                                id: titleText
                                anchors.centerIn: parent
                                text: musicItem.displayTitle
                                color: bar.root.paper
                                font.family: bar.root.mono
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Item {
                            x: 0
                            y: textClip.slideY + 16
                            width: textClip.width
                            height: 16
                            Text {
                                id: artistText
                                anchors.centerIn: parent
                                text: musicItem.displayArtist
                                color: bar.root.paper
                                font.family: bar.root.mono
                                font.pixelSize: 10
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.75
                            }
                        }
                    }
                }

                Text {
                    id: musicIcon
                    anchors.verticalCenter: musicPill.verticalCenter
                    anchors.left: musicPill.left
                    anchors.leftMargin: 5
                    text: bar.root.icoMusic
                    color: bar.root.paper
                    font.family: bar.root.mono
                    font.pixelSize: 9
                    z: 1
                }

                Timer {
                    id: musicTipDelay
                    interval: 320
                    onTriggered: {
                        const p = musicItem.mapToItem(null, musicItem.width / 2, musicItem.height / 2);
                        bar.root.showTooltip(musicItem.tipText, p.x, p.y);
                    }
                }

                Timer {
                    id: musicScrollDebounce
                    interval: 200
                    property bool scrollUp: false
                    onTriggered: {
                        if (scrollUp) bar.root.musicNext();
                        else          bar.root.musicPrev();
                    }
                }

                MouseArea {
                    id: musicMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: musicTipDelay.restart()
                    onExited:  { musicTipDelay.stop(); bar.root.hideTooltip(musicItem.tipText); }
                    onWheel: (e) => {
                        if (e.angleDelta.y === 0) return;
                        musicTipDelay.stop();
                        bar.root.hideTooltip(musicItem.tipText);
                        musicScrollDebounce.scrollUp = e.angleDelta.y > 0;
                        musicScrollDebounce.restart();
                    }
                    onClicked: (e) => {
                        musicTipDelay.stop();
                        bar.root.hideTooltip(musicItem.tipText);
                        if (e.button === Qt.RightButton) bar.root.musicToggle();
                        else                              bar.root.run("hyprctl dispatch togglespecialworkspace music");
                    }
                }
            }

            Item {
                Layout.fillWidth:  bar.root.isHorizontal
                Layout.fillHeight: !bar.root.isHorizontal
            }

            Separator { root: bar.root }

            // Pop-up / overlay openers sit on the inside of the right
            // cluster — weather, display tweaks, screenshots browser.
            Module {
                id: weatherMod
                root: bar.root
                Component.onCompleted: bar.root.weatherAnchorItem = weatherMod
                // Muted middle dot stands in until the first wttr fetch
                // lands; a "?" marks an unreachable network.
                glyph: bar.root.weatherUnavailable ? "?"
                       : (bar.root.weatherLoaded ? bar.root.weatherIcon : "·")
                tooltip: bar.root.weatherUnavailable
                         ? "Weather offline"
                         : (bar.root.weatherLoaded
                            ? bar.root.weatherTempC + "°C"
                            : "Weather…")
                color: bar.root.weatherUnavailable ? bar.root.inkDeep : bar.root.ink
                fontSize: 13
                onActivated: {
                    if (bar.root.weatherVisible) bar.root.weatherVisible = false;
                    else bar.root.openWeather();
                }
                onRightActivated: bar.root.refreshWeather()
            }

            // Aether / Display / Screenshots / Videos moved into the
            // OmniMenu Quick panel (Alt+Space). The bar keeps only the
            // always-glanced status indicators on the right.

            // System indicators read right-to-left as
            //   battery · sound · wifi · bluetooth · cpu · [edge]
            // so the most-glanced item (battery) sits adjacent to the
            // bar-position chevron.
            Module {
                root: bar.root
                glyph: "󰍛"
                tooltip: "CPU " + Math.round(bar.root.cpuVal) + "%"
                color: bar.root.cpuVal > 80 ? bar.root.seal : bar.root.ink
                onActivated: bar.root.run("omarchy-launch-or-focus-tui btop")
            }

            Module {
                root: bar.root
                glyph: bar.root.aiGlyph
                tooltip: bar.root.aiTooltip
                onActivated: bar.root.toggleAi()
            }

            Module {
                root: bar.root
                glyph: bar.root.btIcon
                tooltip: {
                    if (!bar.root.btPowered) return "Bluetooth off";
                    return bar.root.btCount > 0
                        ? "Bluetooth · " + bar.root.btCount + " connected"
                        : "Bluetooth on";
                }
                onActivated: bar.root.run("omarchy-launch-bluetooth")
            }

            Module {
                id: netMod
                root: bar.root
                glyph: bar.root.netIcon
                tooltip: {
                    if (bar.root.netKind === "eth") return "Ethernet";
                    if (bar.root.netKind === "wifi") {
                        const name = bar.root.wifiSsid || "(hidden)";
                        return "Wi-Fi · " + name + " · " + bar.root.wifiSignal + "%";
                    }
                    return "Offline";
                }
                onActivated: bar.root.run("omarchy-launch-wifi")

                // Network-burst dot: traverses the wifi glyph's outermost
                // arc once when a heavy rx+tx burst is detected.
                // Geometry is eyeballed for the Nerd Font wifi icon
                // rendered at fontSize 12 inside the 24x26 Module slot.
                Item {
                    id: arc
                    anchors.fill: parent
                    property real t: 0
                    property real op: 0
                    readonly property real cx: width / 2
                    readonly property real cy: 17
                    readonly property real r:  6

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Qt.lighter(bar.root.seal, 1.7)
                        antialiasing: true
                        opacity: arc.op
                        x: arc.cx - arc.r * Math.cos(Math.PI * arc.t) - width / 2
                        y: arc.cy - arc.r * Math.sin(Math.PI * arc.t) - height / 2
                    }

                    ParallelAnimation {
                        id: arcAnim
                        NumberAnimation {
                            target: arc; property: "t"
                            from: 0; to: 1
                            duration: 700
                            easing.type: Easing.InOutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation { target: arc; property: "op"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 380 }
                            NumberAnimation { target: arc; property: "op"; to: 0; duration: 200; easing.type: Easing.InCubic }
                        }
                    }

                    Connections {
                        target: bar.root
                        function onNetBurst() { arc.t = 0; arcAnim.restart(); }
                    }
                }
            }

            Module {
                root: bar.root
                glyph: bar.root.audioIcon
                tooltip: bar.root.audioMuted
                         ? "Audio muted · " + bar.root.audioVol + "%"
                         : "Audio " + bar.root.audioVol + "%"
                onActivated: bar.root.run("omarchy-launch-audio")
                onRightActivated: bar.root.run("pamixer -t")
            }

            // Surfaces only when omarchy-update-available exits 0. Sits
            // beside the battery so it shares the system-status cluster's
            // line of sight without disturbing the existing icon cadence.
            Module {
                root: bar.root
                visible: bar.root.omarchyUpdateAvailable
                glyph: bar.root.icoUpdate
                tooltip: bar.root.omarchyLatestTag
                         ? "Omarchy update available · " + bar.root.omarchyLatestTag
                         : "Omarchy update available"
                color: bar.root.seal
                fontSize: 10
                onActivated: bar.root.openOmarchyUpdate()
            }

            Module {
                root: bar.root
                glyph: bar.root.batteryIcon()
                // Hide power below 0.05 W: idle Full / Not charging
                // states often report a sub-noise trickle that just
                // adds chatter to the tooltip.
                tooltip: {
                    let s = "Battery " + bar.root.batVal + "%";
                    if (bar.root.batPower >= 0.05) {
                        const sign = bar.root.batState === "Charging"    ? "+"
                                   : bar.root.batState === "Discharging" ? "-"
                                   : "";
                        s += "  " + sign + bar.root.batPower.toFixed(1) + " W";
                    }
                    return s;
                }
                color: bar.root.batVal <= 10 ? bar.root.seal : bar.root.batVal <= 20 ? bar.root.indigo : bar.root.ink
                onActivated: bar.root.run("omarchy-menu power")
            }

            Module {
                root: bar.root
                glyph: bar.root.kbLayout.replace(/ .*/, "").substring(0, 2).toUpperCase()
                tooltip: bar.root.kbLayout
                fontSize: 12
                onActivated: bar.root.run("hyprctl switchxkblayout all next")
            }

            // Module {
            //    root: bar.root
            //    glyph: bar.root.edgeArrow()
            //    tooltip: "Move bar"
            //    onActivated: bar.root.cycleBarEdge()
            // }
        }
    }
}
