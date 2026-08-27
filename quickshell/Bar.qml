//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

import QtQuick
import QtQuick.Layouts

import "./theme"
import "./services"

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 4
        left: 4
        right: 4
    }

    implicitHeight: 30
    color: ThemeManager.backgroundDeep

    // ═══════════════════════════════════════════════════════════════════
    // Main Layout
    // ═══════════════════════════════════════════════════════════════════

    Item {
        anchors.fill: parent

        // ═══════════════════════════════════════════════════════════════
        // Left
        // ═══════════════════════════════════════════════════════════════

        RowLayout {
            id: left

            anchors {
                left: parent.left
                leftMargin: 4
                verticalCenter: parent.verticalCenter
            }

            spacing: 8

            // ───────────────────────────────────────────────────────────
            // Workspaces
            // ───────────────────────────────────────────────────────────

            Row {
                id: workspaceRow

                spacing: 4

                property var wsIds: {
                    const ids = new Set([1, 2, 3, 4, 5])

                    for (const ws of Hyprland.workspaces.values) {
                        if (ws.id > 0)
                            ids.add(ws.id)
                    }

                    return Array.from(ids).sort(
                        (a, b) => a - b
                    )
                }

                Repeater {
                    model: workspaceRow.wsIds

                    delegate: Rectangle {
                        id: workspaceButton

                        required property int modelData

                        readonly property int wsId:
                            modelData

                        readonly property var workspace:
                            Hyprland.workspaces.values.find(
                                w => w.id === wsId
                            )

                        readonly property bool active:
                            Hyprland.focusedWorkspace?.id === wsId

                        readonly property bool occupied:
                            workspace !== undefined

                        readonly property bool urgent:
                            workspace?.urgent ?? false

                        width: bar.implicitHeight - 8
                        height: bar.implicitHeight - 8

                        color: urgent
                            ? ThemeManager.danger
                            : active
                                ? ThemeManager.accent
                                : "transparent"

                        Text {
                            anchors.fill: parent

                            text: workspaceButton.wsId

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontNormal

                            font.weight:
                                workspaceButton.occupied
                                    ? ThemeManager.fontHeavy
                                    : ThemeManager.fontBold

                            color:
                                workspaceButton.active ||
                                workspaceButton.urgent
                                    ? ThemeManager.backgroundDeep
                                    : workspaceButton.occupied
                                        ? ThemeManager.accent
                                        : ThemeManager.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent

                            cursorShape:
                                workspaceButton.workspace
                                    ? Qt.PointingHandCursor
                                    : Qt.ArrowCursor

                            onClicked: {
                                if (workspaceButton.workspace)
                                    workspaceButton.workspace.activate()
                            }
                        }
                    }
                }
            }

            // ───────────────────────────────────────────────────────────
            // Active Window
            // ───────────────────────────────────────────────────────────

            Rectangle {
                id: activeWindowContainer

                readonly property var activeWindow:
                    Hyprland.activeToplevel

                readonly property bool hasActiveWindow:
                    activeWindow !== null &&
                    activeWindow.workspace ===
                        Hyprland.focusedWorkspace

                visible: hasActiveWindow

                color: ThemeManager.surface

                implicitHeight:
                    bar.implicitHeight - 8

                implicitWidth:
                    Math.min(
                        activeWindowText.implicitWidth + 16,
                        250
                    )

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width: 2

                    color: ThemeManager.accent
                }

                Text {
                    id: activeWindowText

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter

                        leftMargin: 10
                        rightMargin: 6
                    }

                    text:
                        activeWindowContainer.activeWindow?.title ?? ""

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy

                    color:
                        ThemeManager.text

                    elide:
                        Text.ElideRight

                    maximumLineCount:
                        1
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Right
        // ═══════════════════════════════════════════════════════════════

        Item {
            id: rightContainer

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }

            implicitWidth:
                rightRow.implicitWidth

            implicitHeight:
                rightRow.implicitHeight

            // ───────────────────────────────────────────────────────────
            // Control Center Mouse Area
            //
            // This covers the whole right section.
            // The tray has a higher z value so tray clicks pass through
            // to the tray icons instead.
            // ───────────────────────────────────────────────────────────

            MouseArea {
                id: controlCenterMouseArea

                anchors.fill: parent

                z: 0

                cursorShape:
                    Qt.PointingHandCursor

                onClicked:
                    ControlCenterState.toggle()
            }

            // ───────────────────────────────────────────────────────────
            // Right Row
            // ───────────────────────────────────────────────────────────

            RowLayout {
                id: rightRow

                anchors.fill: parent

                spacing: 16

                // ───────────────────────────────────────────────────────
                // System Tray
                // ───────────────────────────────────────────────────────

                RowLayout {
                    id: trayRow

                    spacing: 10

                    z: 2

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            required property var modelData

                            width: 16
                            height: 16

                            Image {
                                anchors.fill: parent

                                source:
                                    modelData.icon

                                sourceSize:
                                    Qt.size(16, 16)
                            }

                            MouseArea {
                                anchors.fill: parent

                                z: 10

                                cursorShape:
                                    Qt.PointingHandCursor

                                acceptedButtons:
                                    Qt.LeftButton |
                                    Qt.RightButton

                                onClicked: (mouse) => {
                                    if (
                                        mouse.button ===
                                        Qt.RightButton
                                    ) {
                                        modelData.display(
                                            bar,
                                            mouse.x,
                                            mouse.y
                                        )
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }

                // ───────────────────────────────────────────────────────
                // Volume
                // ───────────────────────────────────────────────────────

                Text {
                    id: volumeText

                    z: 1

                    readonly property var sink:
                        Pipewire.defaultAudioSink

                    readonly property int volume:
                        sink?.audio
                            ? Math.round(
                                sink.audio.volume * 100
                            )
                            : 0

                    readonly property bool muted:
                        sink?.audio?.muted ?? false

                    PwObjectTracker {
                        objects: [volumeText.sink]
                    }

                    text:
                        muted
                            ? "Muted"
                            : volume + "%"

                    color:
                        muted
                            ? ThemeManager.textMuted
                            : ThemeManager.accent

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy
                }

                // ───────────────────────────────────────────────────────
                // Wi-Fi
                // ───────────────────────────────────────────────────────

                Text {
                    id: wifiText

                    z: 1

                    readonly property var wifiDevice:
                        Networking.devices.values.find(
                            device => device.type === 1
                        )

                    readonly property var connectedNetwork:
                        wifiDevice?.networks.values.find(
                            network => network.connected
                        )

                    readonly property bool wifiEnabled:
                        Networking.wifiEnabled

                    readonly property bool connected:
                        wifiDevice?.connected ?? false

                    readonly property int signalStrength:
                        connectedNetwork
                            ? Math.round(
                                connectedNetwork.signalStrength * 100
                            )
                            : 0

                    text:
                        !wifiEnabled
                            ? "Off"
                            : connected
                                ? "  " + signalStrength + "%"
                                : ""

                    color:
                        connected
                            ? ThemeManager.info
                            : ThemeManager.textMuted

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy
                }

                // ───────────────────────────────────────────────────────
                // Bluetooth
                // ───────────────────────────────────────────────────────

                Text {
                    id: bluetoothText

                    z: 1

                    readonly property var bluetoothAdapter:
                        Bluetooth.defaultAdapter

                    readonly property bool bluetoothEnabled:
                        bluetoothAdapter?.enabled ?? false

                    readonly property int connectedDevices:
                        Bluetooth.devices.values.filter(
                            device => device.connected
                        ).length

                    text:
                        !bluetoothEnabled
                            ? "Off"
                            : connectedDevices > 0
                                ? "BT: " + connectedDevices
                                : "BT"

                    color:
                        connectedDevices
                            ? ThemeManager.info
                            : bluetoothEnabled
                                ? ThemeManager.accent
                                : ThemeManager.textMuted

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy
                }

                // ───────────────────────────────────────────────────────
                // Power Profile
                // ───────────────────────────────────────────────────────

                Text {
                    id: powerProfileText

                    z: 1

                    readonly property var profile:
                        PowerProfiles.profile

                    text: {
                        switch (profile) {
                        case PowerProfile.PowerSaver:
                            return "Stealth"

                        case PowerProfile.Balanced:
                            return "Steady"

                        case PowerProfile.Performance:
                            return "Stride"

                        default:
                            return "Steady"
                        }
                    }

                    color: {
                        switch (profile) {
                        case PowerProfile.PowerSaver:
                            return ThemeManager.success

                        case PowerProfile.Balanced:
                            return ThemeManager.accent

                        case PowerProfile.Performance:
                            return ThemeManager.danger

                        default:
                            return ThemeManager.accent
                        }
                    }

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy
                }

                // ───────────────────────────────────────────────────────
                // Battery
                // ───────────────────────────────────────────────────────

                Text {
                    id: batteryText

                    z: 1

                    property var battery:
                        UPower.displayDevice

                    property bool pluggedIn:
                        !UPower.onBattery

                    property bool shouldBlink:
                        battery.ready &&
                        !pluggedIn &&
                        battery.percentage <= 0.05

                    function batteryColor(pct, plugged) {
                        if (plugged)
                            return ThemeManager.success

                        if (pct <= 0.10)
                            return ThemeManager.danger

                        if (pct <= 0.20)
                            return ThemeManager.warning

                        if (pct <= 0.30)
                            return ThemeManager.peach

                        return ThemeManager.accent
                    }

                    text:
                        battery.ready
                            ? Math.round(
                                battery.percentage * 100
                            ) + "%"
                            : ""

                    color:
                        battery.ready
                            ? batteryColor(
                                battery.percentage,
                                pluggedIn
                            )
                            : ThemeManager.accent

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy

                    onShouldBlinkChanged: {
                        if (shouldBlink) {
                            blinkAnim.restart()
                        } else {
                            blinkAnim.stop()
                            opacity = 1.0
                        }
                    }

                    SequentialAnimation {
                        id: blinkAnim

                        loops:
                            Animation.Infinite

                        NumberAnimation {
                            target: batteryText

                            property: "opacity"

                            from: 1.0
                            to: 0.2

                            duration: 500
                        }

                        NumberAnimation {
                            target: batteryText

                            property: "opacity"

                            from: 0.2
                            to: 1.0

                            duration: 500
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Center
        // ═══════════════════════════════════════════════════════════════

        Text {
            id: clock

            anchors.centerIn: parent

            font.family:
                ThemeManager.fontFamily

            font.pixelSize:
                ThemeManager.fontNormal

            font.weight:
                ThemeManager.fontHeavy

            color:
                ThemeManager.text

            function refresh() {
                text = Qt.formatDateTime(
                    new Date(),
                    "MMM dd  hh:mm"
                )
            }

            Component.onCompleted:
                refresh()

            Timer {
                interval: 1000

                running: true
                repeat: true

                onTriggered:
                    clock.refresh()
            }
        }
    }
}
