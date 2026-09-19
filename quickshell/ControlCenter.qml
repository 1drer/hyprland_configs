import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "./theme"
import "./modules"
import "./services"

// ─────────────────────────────────────────────────────────────────────
// JITTER-FREE CONTROL CENTER
//
// The window NEVER resizes. It is a fixed-size transparent overlay
// anchored top-right. The visible panel (panelSurface) hugs `mainColumn`
// from the top and can grow/shrink freely inside, without ever touching
// the surface geometry — window resize is the thing that causes
// compositor-side stutter (quickshell#18), so it simply never happens.
//
//   * `mask`  → the compositor only receives clicks in the panel region;
//               the transparent strip below the panel is click-through.
//   * `HyprlandWindow.visibleMask` → renders only the actual panel region
//               so the empty overlay costs (almost) nothing, even with
//               blur enabled on the wallpaper.
//   * The expanded Wi-Fi / Bluetooth lists are scrollable and capped so
//     the fixed height always fits every possible content state.
// ─────────────────────────────────────────────────────────────────────

PanelWindow {
    id: root

    property int barHeight: 28
    property int barTopMargin: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: barHeight + barTopMargin + 4
        right: 4
    }

    // ═══════════════════════════════════════════════════════════════
    // FIXED SIZING
    // ═══════════════════════════════════════════════════════════════

    implicitWidth: 430

    readonly property int tileHeight: 44
    readonly property int networkRowHeight: 46
    readonly property int actionHeight: 26
    readonly property int panelPadding: 32

    readonly property int columnSpacing: 8

    // Lists inside the expanded sections scroll after this much.
    readonly property int expandedContentCap: 400
    readonly property int expandedSectionMaxHeight:
        root.expandedContentCap + 20

    // Tallest the panel can ever be:
    //   the 3 tile rows            (wifi/bt, airplane/night, power)
    //   3 slider-height rows       (volume, brightness, warmth)
    //   one expanded section       (wifi and bluetooth are mutually exclusive)
    //   spacing between rows, and the outer padding.
    readonly property int fixedImplicitHeight:
        root.panelPadding +
        root.tileHeight * 3 +
        root.actionHeight * 3 +
        root.expandedSectionMaxHeight +
        root.columnSpacing * 6

    implicitHeight: root.fixedImplicitHeight

    // ═══════════════════════════════════════════════════════════════
    // MASK / VISIBILITY
    // ═══════════════════════════════════════════════════════════════

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Region {
        id: panelRegion

        item: panelSurface
    }

    mask: panelRegion
    HyprlandWindow.visibleMask: panelRegion

    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════

    property bool wifiExpanded: false
    property bool bluetoothExpanded: false

    property int wifiView: 0

    property string wifiPassword: ""
    property var selectedWifi: null

    property string addNetworkName: ""
    property string addNetworkPassword: ""
    property bool addNetworkOpen: false

    property int brightness: 50

    property bool airplaneMode: false

    property bool nightMode: false
    property int nightTemperature: 3500

    // True while hypridle is stopped, i.e. idle actions (lock, suspend)
    // are suppressed. Mirrors the night-mode convention: the panel
    // re-reads the real process state on open and after every toggle.
    property bool idleInhibited: false

    // ═══════════════════════════════════════════════════════════════
    // NATIVE DEVICES
    // ═══════════════════════════════════════════════════════════════

    readonly property var wifiDevice:
        Networking.devices.values.find(
            device => device.type === DeviceType.Wifi
        )

    readonly property var connectedWifi:
        wifiDevice
            ? wifiDevice.networks.values.find(
                  network => network.connected
              )
            : null

    readonly property var bluetoothAdapter:
        Bluetooth.defaultAdapter

    readonly property var audioSink:
        Pipewire.defaultAudioSink

    // ═══════════════════════════════════════════════════════════════
    // SORTED WIFI MODELS
    // ═══════════════════════════════════════════════════════════════

    ScriptModel {
        id: wifiNetworksModel

        values:
            root.wifiDevice
                ? [...root.wifiDevice.networks.values].sort(
                      (a, b) => {
                          if (a.known !== b.known)
                              return a.known ? -1 : 1

                          if (a.connected !== b.connected)
                              return a.connected ? -1 : 1

                          return root.wifiSignal(b) -
                                 root.wifiSignal(a)
                      }
                  )
                : []
    }

    // Saved connection names come from NetworkManager profiles (nmcli),
    // so the saved list also includes networks that are configured but
    // currently out of range — the device's `networks` model only
    // contains what the last scan saw.
    property var savedConnectionNames: []

    ScriptModel {
        id: savedWifiModel

        values: {
            const device = root.wifiDevice

            const available =
                device
                    ? [...device.networks.values]
                        .filter(network => network.known)
                    : []

            available.sort(
                (a, b) => {
                    if (a.connected !== b.connected)
                        return a.connected ? -1 : 1

                    return root.wifiSignal(b) -
                           root.wifiSignal(a)
                }
            )

            const availableNames =
                new Set(available.map(network => network.name))

            const unavailable = []

            for (const name of root.savedConnectionNames) {
                if (availableNames.has(name))
                    continue

                unavailable.push(
                    root.makeUnavailableEntry(name)
                )
            }

            unavailable.sort(
                (a, b) => a.name.localeCompare(b.name)
            )

            return [...available, ...unavailable]
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // AUDIO TRACKING
    // ═══════════════════════════════════════════════════════════════

    PwObjectTracker {
        objects: [root.audioSink]
    }

    // ═══════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════

    function wifiSignal(network) {
        if (!network)
            return 0

        let value = Number(network.signalStrength)

        if (isNaN(value))
            return 0

        if (value <= 1)
            value *= 100

        return Math.max(
            0,
            Math.min(
                100,
                Math.round(value)
            )
        )
    }

    function wifiIcon(network) {
        if (!Networking.wifiEnabled)
            return "󰤭"

        if (!network)
            return "󰤯"

        const signal = root.wifiSignal(network)

        if (signal >= 80)
            return "󰤨"

        if (signal >= 60)
            return "󰤥"

        if (signal >= 40)
            return "󰤢"

        if (signal >= 20)
            return "󰤟"

        return "󰤯"
    }

    function wifiTileIcon() {
        if (!Networking.wifiEnabled)
            return "󰤭"

        if (!root.connectedWifi)
            return "󰤯"

        return root.wifiIcon(root.connectedWifi)
    }

    function isOpenWifi(network) {
        if (!network)
            return false

        return network.security === WifiSecurityType.Open
    }

    // Shows a lock only for networks with an explicit encryption type.
    // Open networks are reported as `Unknown` once saved/known, so that
    // must not be treated as encrypted either.
    function isNetworkLocked(network) {
        if (!network)
            return false

        return network.security !== WifiSecurityType.Open &&
               network.security !== WifiSecurityType.Unknown
    }

    function bluetoothIcon() {
        if (
            !root.bluetoothAdapter ||
            !root.bluetoothAdapter.enabled
        )
            return "󰂲"

        return "󰂯"
    }

    function volumeIcon() {
        if (
            !root.audioSink ||
            !root.audioSink.audio
        )
            return "󰕾"

        if (root.audioSink.audio.muted)
            return "󰝟"

        const volume =
            root.audioSink.audio.volume

        if (volume <= 0.01)
            return "󰕿"

        if (volume <= 0.33)
            return "󰖀"

        return "󰕾"
    }

    function brightnessIcon() {
        if (root.brightness <= 20)
            return "󰃞"

        if (root.brightness <= 40)
            return "󰃝"

        if (root.brightness <= 70)
            return "󰃟"

        return "󰃠"
    }

    function powerProfileName(profile) {
        switch (profile) {
        case PowerProfile.Performance:
            return "Stride"

        case PowerProfile.PowerSaver:
            return "Stealth"

        default:
            return "Steady"
        }
    }

    function powerProfileColor(profile) {
        switch (profile) {
        case PowerProfile.Performance:
            return ThemeManager.danger

        case PowerProfile.PowerSaver:
            return ThemeManager.success

        default:
            return ThemeManager.accent
        }
    }

    function powerProfileIcon(profile) {
        switch (profile) {
        case PowerProfile.Performance:
            return "󰓅"

        case PowerProfile.PowerSaver:
            return "󰾆"

        default:
            return "󰗑"
        }
    }

    function cyclePowerProfile() {
        if (!PowerProfiles.hasPerformanceProfile) {
            PowerProfiles.profile =
                PowerProfiles.profile ===
                    PowerProfile.PowerSaver
                        ? PowerProfile.Balanced
                        : PowerProfile.PowerSaver
        } else {
            switch (PowerProfiles.profile) {
            case PowerProfile.Balanced:
                PowerProfiles.profile =
                    PowerProfile.Performance
                break

            case PowerProfile.Performance:
                PowerProfiles.profile =
                    PowerProfile.PowerSaver
                break

            default:
                PowerProfiles.profile =
                    PowerProfile.Balanced
            }
        }

        keyboardFocus.forceActiveFocus()
    }

    function toggleBluetooth() {
        if (!bluetoothAdapter)
            return

        bluetoothAdapter.enabled =
            !bluetoothAdapter.enabled
    }

    function toggleWifi() {
        Networking.wifiEnabled =
            !Networking.wifiEnabled
    }

    function toggleWifiExpand() {
        root.wifiExpanded = !root.wifiExpanded

        root.bluetoothExpanded = false

        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled =
                root.wifiExpanded
    }

    function toggleBluetoothExpand() {
        root.bluetoothExpanded =
            !root.bluetoothExpanded

        root.wifiExpanded = false

        if (root.bluetoothAdapter)
            root.bluetoothAdapter.discovering =
                root.bluetoothExpanded
    }

    // Placeholder for a saved network that isn't currently in range.
    // It carries just enough fields for the saved-network delegate,
    // with `available: false` so the Connect button stays hidden.
    function makeUnavailableEntry(name) {
        return {
            name: name,
            known: true,
            connected: false,
            available: false,
            signalStrength: 0
        }
    }

    function forgetSaved(network) {
        if (!network)
            return

        if (network.available !== false) {
            network.forget()
        } else {
            forgetProcess.command = [
                "nmcli",
                "connection",
                "delete",
                network.name
            ]
            forgetProcess.running = true
        }

        savedConnectionsRefreshTimer.restart()
    }

    function toggleAirplane() {
        airplaneProcess.running = true
    }

    function toggleNightMode() {
        root.nightMode = !root.nightMode

        if (root.nightMode) {
            nightModeProcess.command = [
                "sh",
                "-c",
                "systemctl --user stop cc-hyprsunset " +
                "2>/dev/null; " +
                "systemctl --user reset-failed cc-hyprsunset " +
                "2>/dev/null; " +
                "pkill -x hyprsunset 2>/dev/null; " +
                "systemd-run --user --unit=cc-hyprsunset --collect " +
                "--quiet hyprsunset --temperature " +
                root.nightTemperature
            ]
        } else {
            nightModeProcess.command = [
                "sh",
                "-c",
                "systemctl --user stop cc-hyprsunset " +
                "2>/dev/null; " +
                "pkill -x hyprsunset 2>/dev/null"
            ]
        }

        nightModeProcess.running = true
    }

    function toggleIdleInhibit() {
        root.idleInhibited = !root.idleInhibited

        idleInhibitProcess.running = true
    }

    function setNightTemperature(value) {
        const temp = Math.max(
            1000,
            Math.min(
                6500,
                Math.round(value / 100) * 100
            )
        )

        root.nightTemperature = temp

        root.persistNightTemperature()

        if (root.nightMode)
            nightTemperatureTimer.restart()
    }

    // ═══════════════════════════════════════════════════════════════
    // WIFI CONNECTION
    // ═══════════════════════════════════════════════════════════════

    function connectWifi(network) {
        if (!network)
            return

        if (network.known) {
            network.connect()
            return
        }

        if (root.isOpenWifi(network)) {
            network.connect()
            return
        }

        selectedWifi = network
        wifiPassword = ""

        passwordDialog.visible = true

        Qt.callLater(() => {
            passwordField.forceActiveFocus()
        })
    }

    function connectWifiPassword() {
        if (!selectedWifi)
            return

        if (wifiPassword.length === 0)
            return

        selectedWifi.connectWithPsk(
            wifiPassword
        )

        wifiPassword = ""
        selectedWifi = null
        passwordDialog.visible = false

        keyboardFocus.forceActiveFocus()
    }

    function cancelWifiPassword() {
        wifiPassword = ""
        selectedWifi = null
        passwordDialog.visible = false

        keyboardFocus.forceActiveFocus()
    }

    // ═══════════════════════════════════════════════════════════════
    // ADD NETWORK
    // ═══════════════════════════════════════════════════════════════

    function addNetwork() {
        const ssid =
            root.addNetworkName.trim()

        if (ssid.length === 0)
            return

        if (
            !root.addNetworkOpen &&
            root.addNetworkPassword.length === 0
        )
            return

        if (root.addNetworkOpen) {
            addNetworkProcess.command = [
                "nmcli",
                "device",
                "wifi",
                "connect",
                ssid
            ]
        } else {
            addNetworkProcess.command = [
                "nmcli",
                "device",
                "wifi",
                "connect",
                ssid,
                "password",
                root.addNetworkPassword
            ]
        }

        addNetworkProcess.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: brightnessRead

        command: [
            "brightnessctl",
            "-m"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()

                if (!output)
                    return

                const parts =
                    output.split(",")

                if (parts.length < 4)
                    return

                const value =
                    parseInt(
                        parts[3].replace(
                            "%",
                            ""
                        )
                    )

                if (!isNaN(value))
                    root.brightness = value
            }
        }
    }

    Process {
        id: brightnessWrite
    }

    Process {
        id: addNetworkProcess

        onExited: {
            if (exitCode === 0) {
                root.addNetworkName = ""
                root.addNetworkPassword = ""
                root.addNetworkOpen = false

                root.wifiView = 0

                if (root.wifiDevice)
                    root.wifiDevice.scannerEnabled =
                        true

                savedConnectionsRefreshTimer.restart()
            }
        }
    }

    // Reads all saved NetworkManager connection profiles so the saved
    // list can show networks that are configured but out of range.
    Process {
        id: savedConnectionsRead

        command: [
            "nmcli",
            "-t",
            "-f",
            "NAME,TYPE",
            "connection",
            "show"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const names = []

                for (
                    const line of this.text.split("\n")
                ) {
                    if (!line)
                        continue

                    // nmcli -t escapes the field separator as `\:`,
                    // so split on unescaped colons only.
                    const fields = []
                    let field = ""

                    for (
                        let i = 0;
                        i < line.length;
                        ++i
                    ) {
                        const ch = line[i]

                        if (
                            ch === "\\" &&
                            i + 1 < line.length &&
                            line[i + 1] === ":"
                        ) {
                            field += ":"
                            i++
                        } else if (ch === ":") {
                            fields.push(field)
                            field = ""
                        } else {
                            field += ch
                        }
                    }

                    fields.push(field)

                    if (
                        fields[1] === "802-11-wireless"
                    )
                        names.push(fields[0])
                }

                root.savedConnectionNames = names
            }
        }
    }

    Process {
        id: forgetProcess
    }

    // Small delay so nmcli has actually applied a forget/add before the
    // saved-profile list is re-read.
    Timer {
        id: savedConnectionsRefreshTimer

        interval: 150
        repeat: false

        onTriggered: {
            savedConnectionsRead.running = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // AIRPLANE MODE
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: airplaneRead

        command: [
            "sh",
            "-c",
            "nmcli radio all | tail -n +2"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()

                if (!output)
                    return

                /*
                 * nmcli radio all normally reports:
                 *
                 * WIFI-HW  WIFI  WWAN-HW  WWAN
                 * enabled  enabled  enabled  enabled
                 *
                 * Airplane mode is considered active when
                 * all software radios are disabled.
                 */
                const lines =
                    output.split("\n")

                let wifiOn = false
                let wwanOn = false

                for (let line of lines) {
                    const parts =
                        line.trim().split(/\s+/)

                    if (parts.length < 4)
                        continue

                    if (parts[1] === "enabled")
                        wifiOn = true

                    if (parts[3] === "enabled")
                        wwanOn = true
                }

                root.airplaneMode =
                    !wifiOn && !wwanOn
            }
        }
    }

    Process {
        id: airplaneProcess

        command: [
            "sh",
            "-c",
            "if nmcli radio wifi | grep -q enabled || " +
            "nmcli radio wwan | grep -q enabled; then " +
            "nmcli radio all off; " +
            "rfkill block wifi; " +
            "rfkill block bluetooth; " +
            "else " +
            "rfkill unblock wifi; " +
            "rfkill unblock bluetooth; " +
            "nmcli radio all on; " +
            "fi"
        ]

        onExited: {
            airplaneRead.running = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NIGHT MODE (hyprsunset)
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: nightModeProcess

        // Don't sample state immediately — systemd-run starting the
        // unit and hyprsunset actually forking can lag behind this
        // process exiting. Debounce via nightModeVerifyTimer instead
        // of reading state right away, or we can read a stale "off".
        onExited: {
            nightModeVerifyTimer.restart()
        }
    }

    Process {
        id: nightModeSetProcess

        onExited: {
            nightModeVerifyTimer.restart()
        }
    }

    // Apply temperature only after the slider stops moving.
    // This prevents hyprsunset from being restarted for every
    // tiny slider movement.
    Timer {
        id: nightTemperatureTimer

        interval: 120
        repeat: false

        onTriggered: {
            if (!root.nightMode)
                return

            nightModeSetProcess.command = [
                "sh",
                "-c",
                "systemctl --user stop cc-hyprsunset " +
                "2>/dev/null; " +
                "systemctl --user reset-failed cc-hyprsunset " +
                "2>/dev/null; " +
                "pkill -x hyprsunset 2>/dev/null; " +
                "systemd-run --user --unit=cc-hyprsunset --collect " +
                "--quiet hyprsunset --temperature " +
                root.nightTemperature
            ]

            nightModeSetProcess.running = true
        }
    }

    // Gives systemd-run a moment to actually get the unit + process
    // up (or down) before we ask it what happened.
    Timer {
        id: nightModeVerifyTimer

        interval: 250
        repeat: false

        onTriggered: {
            nightModeRead.running = true
        }
    }

    Process {
        id: nightModeRead

        // Check the unit itself rather than a raw process-name match —
        // more precise, and avoids matching a stray/leftover hyprsunset
        // that isn't actually the one we manage.
        command: [
            "sh",
            "-c",
            "systemctl --user is-active --quiet cc-hyprsunset " +
            "&& echo 1 || echo 0"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()
                root.nightMode = output === "1"
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // IDLE INHIBITOR (hypridle)
    // ═══════════════════════════════════════════════════════════════

    // Killing hypridle suppresses all idle actions (lock, suspend, etc.);
    // restarting it re-enables them. The panel flips the tile state
    // immediately on click and lets the read-back below confirm it.
    Process {
        id: idleInhibitProcess

        command: [
            "sh",
            "-c",
            "if pgrep -x hypridle >/dev/null; then " +
            "pkill -x hypridle; " +
            "else " +
            "setsid -f hypridle >/dev/null 2>&1; " +
            "fi"
        ]

        onExited: {
            idleInhibitVerifyTimer.restart()
        }
    }

    // pkill/pgrep can race — give the old process a moment to actually
    // die before sampling state, same as nightModeVerifyTimer.
    Timer {
        id: idleInhibitVerifyTimer

        interval: 250
        repeat: false

        onTriggered: {
            idleInhibitRead.running = true
        }
    }

    Process {
        id: idleInhibitRead

        // 1 = hypridle is NOT running = idle is being inhibited.
        command: [
            "sh",
            "-c",
            "pgrep -x hypridle >/dev/null && echo 0 || echo 1"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()
                root.idleInhibited = output === "1"
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NIGHT TEMPERATURE PERSISTENCE
    // ═══════════════════════════════════════════════════════════════

    // This panel can be destroyed and recreated each time it's
    // opened/closed (e.g. loader-based visibility), which would
    // otherwise reset nightTemperature back to its declared default
    // every time. Persist it to a small state file so the slider
    // position — and the temperature actually applied to
    // hyprsunset — survive across open/close cycles.

    readonly property string nightTempStateFile:
        "$HOME/.cache/quickshell/night-temperature"

    function persistNightTemperature() {
        nightTempWrite.command = [
            "sh",
            "-c",
            "mkdir -p \"$HOME/.cache/quickshell\" && " +
            "echo " + root.nightTemperature + " > " +
            root.nightTempStateFile
        ]

        nightTempWrite.running = true
    }

    Process {
        id: nightTempWrite
    }

    Process {
        id: nightTempRead

        command: [
            "sh",
            "-c",
            "cat " + root.nightTempStateFile + " 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()

                const value =
                    parseInt(output)

                if (
                    !isNaN(value) &&
                    value >= 1000 &&
                    value <= 6500
                ) {
                    root.nightTemperature = value
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // BRIGHTNESS / AIRPLANE UPDATE
    // ═══════════════════════════════════════════════════════════════

    Timer {
        interval: 50
        running: true
        repeat: true

        onTriggered: {
            brightnessRead.running = true
            airplaneRead.running = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STARTUP
    // ═══════════════════════════════════════════════════════════════

    Component.onCompleted: {
        nightTempRead.running = true

        brightnessRead.running = true
        airplaneRead.running = true
        nightModeRead.running = true
        idleInhibitRead.running = true
        savedConnectionsRead.running = true

        if (wifiDevice)
            wifiDevice.scannerEnabled = true

        keyboardFocus.forceActiveFocus()
        focusGrab.active = true
    }

    // Refresh the saved-profile list whenever it becomes visible.
    onWifiExpandedChanged: {
        if (root.wifiExpanded)
            savedConnectionsRead.running = true
    }

    onWifiViewChanged: {
        if (root.wifiView === 1)
            savedConnectionsRead.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // KEYBOARD FOCUS / ESC
    // ═══════════════════════════════════════════════════════════════

    Item {
        id: keyboardFocus

        anchors.fill: parent

        focus: true

        Keys.onEscapePressed: {
            if (passwordDialog.visible) {
                root.cancelWifiPassword()
                event.accepted = true
                return
            }

            if (root.wifiView !== 0) {
                root.wifiView = 0
                event.accepted = true
                return
            }

            if (root.wifiExpanded) {
                root.wifiExpanded = false
                event.accepted = true
                return
            }

            if (root.bluetoothExpanded) {
                root.bluetoothExpanded = false
                event.accepted = true
                return
            }

            ControlCenterState.close()

            event.accepted = true
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CLICK OUTSIDE TO CLOSE
    // ═══════════════════════════════════════════════════════════════

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]

        onCleared: {
            if (passwordDialog.visible)
                return

            ControlCenterState.close()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND (the visible panel — hugs mainColumn from the top)
    // ═══════════════════════════════════════════════════════════════

    Rectangle {
        id: panelSurface

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        height: root.contentHeight

        // Keep the input mask + hyprland visible-mask in sync with the
        // panel's current geometry.
        onHeightChanged: {
            if (panelRegion)
                panelRegion.changed()
        }

        radius: 0

        color:
            ThemeManager.backgroundDeep

        border.width: 2

        border.color:
            ThemeManager.accent
    }

    readonly property int contentHeight:
        mainColumn.implicitHeight + root.panelPadding

    // ═══════════════════════════════════════════════════════════════
    // MAIN CONTENT
    // ═══════════════════════════════════════════════════════════════

    ColumnLayout {
        id: mainColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 16

        spacing: 8

        // ═══════════════════════════════════════════════════════════
        // WIFI + BLUETOOTH
        // ═══════════════════════════════════════════════════════════

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            // ───────────────────────────────────────────────────────
            // WIFI
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon: root.wifiTileIcon()

                label:
                    root.connectedWifi
                        ? root.connectedWifi.name
                        : "Wi-Fi"

                checked:
                    Networking.wifiEnabled

                expandable: true

                expanded:
                    root.wifiExpanded

                activate:
                    () => root.toggleWifi()

                expand:
                    () => root.toggleWifiExpand()
            }

            // ───────────────────────────────────────────────────────
            // BLUETOOTH
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon: root.bluetoothIcon()

                label: "Bluetooth"

                checked:
                    root.bluetoothAdapter &&
                    root.bluetoothAdapter.enabled

                expandable: true

                expanded:
                    root.bluetoothExpanded

                activate:
                    () => root.toggleBluetooth()

                expand:
                    () => root.toggleBluetoothExpand()
            }
        }

        // ═══════════════════════════════════════════════════════════
        // WIFI EXPANDED
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            visible:
                root.wifiExpanded

            Layout.fillWidth: true

            // Bounded: the list scrolls instead of growing forever,
            // so mainColumn's height stays within the fixed window.
            implicitHeight:
                Math.min(
                    root.expandedContentCap,
                    wifiColumn.implicitHeight
                ) + 20

            radius: 0

            color:
                ThemeManager.background

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            Flickable {
                id: wifiScroller

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }

                anchors.margins: 10

                clip: true

                contentWidth: width
                contentHeight:
                    wifiColumn.implicitHeight

                interactive:
                    contentHeight > height

                ColumnLayout {
                    id: wifiColumn

                    width:
                        wifiScroller.width

                    spacing: 6

                    // ───────────────────────────────────────────────
                    // WIFI LIST
                    // ───────────────────────────────────────────────

                    ColumnLayout {
                        visible:
                            root.wifiView === 0

                        Layout.fillWidth: true

                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Wi-Fi"

                                color:
                                    ThemeManager.text

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontSmall + 1

                                font.weight:
                                    ThemeManager.fontBold

                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 28
                                height: 28

                                color:
                                    wifiRefreshArea.containsMouse
                                        ? ThemeManager.surfaceSecondary
                                        : ThemeManager.surface

                                MouseArea {
                                    id: wifiRefreshArea

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        if (root.wifiDevice)
                                            root.wifiDevice.scannerEnabled =
                                                true
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰑐"

                                    color:
                                        root.wifiDevice &&
                                        root.wifiDevice.scannerEnabled
                                            ? ThemeManager.accent
                                            : ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 16
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight:
                                root.networkRowHeight

                            color:
                                addNetworkRowArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                            border.width: 1
                            border.color:
                                ThemeManager.surfaceSecondary

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 9

                                Text {
                                    text: "󰐕"

                                    color:
                                        ThemeManager.accent

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 19
                                }

                                Text {
                                    text: "Add Network"

                                    color:
                                        ThemeManager.text

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize:
                                        ThemeManager.fontTiny + 1

                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "󰅂"

                                    color:
                                        ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 17
                                }
                            }

                            MouseArea {
                                id: addNetworkRowArea

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    root.wifiView = 2
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight:
                                root.networkRowHeight

                            color:
                                savedNetworksRowArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                            border.width: 1
                            border.color:
                                ThemeManager.surfaceSecondary

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 9

                                Text {
                                    text: "󰿆"

                                    color:
                                        ThemeManager.accent

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 19
                                }

                                Text {
                                    text: "View Saved Networks"

                                    color:
                                        ThemeManager.text

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize:
                                        ThemeManager.fontTiny + 1

                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "󰅂"

                                    color:
                                        ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 17
                                }
                            }

                            MouseArea {
                                id: savedNetworksRowArea

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    root.wifiView = 1
                            }
                        }

                        Repeater {
                            model:
                                wifiNetworksModel

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true

                                Layout.preferredHeight:
                                    root.networkRowHeight

                                color:
                                    networkArea.containsMouse
                                        ? ThemeManager.surfaceSecondary
                                        : modelData.connected
                                            ? ThemeManager.surfaceSecondary
                                            : ThemeManager.surface
                                border.width: 1

                                border.color:
                                    modelData.connected
                                        ? ThemeManager.accent
                                        : ThemeManager.surfaceSecondary

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 7

                                    spacing: 8

                                    Text {
                                        text:
                                            root.wifiIcon(
                                                modelData
                                            )

                                        color:
                                            modelData.connected
                                                ? ThemeManager.info
                                                : ThemeManager.textMuted

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text:
                                            modelData.name

                                        color:
                                            ThemeManager.text

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1

                                        Layout.fillWidth: true

                                        elide:
                                            Text.ElideRight
                                    }

                                    Text {
                                        text:
                                            root.isNetworkLocked(modelData)
                                                ? "󰌾"
                                                : ""

                                        color:
                                            ThemeManager.textMuted

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize: 14
                                    }

                                    Rectangle {
                                        visible:
                                            !modelData.connected

                                        width: 64
                                        height:
                                            root.actionHeight

                                        color:
                                            connectNetworkArea.containsMouse
                                                ? ThemeManager.accentDim
                                                : ThemeManager.accent

                                        Text {
                                            anchors.centerIn: parent

                                            text:
                                                modelData.known
                                                    ? "Connect"
                                                    : "Join"

                                            color:
                                                ThemeManager.background

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize:
                                                ThemeManager.fontTiny + 1

                                            font.weight:
                                                ThemeManager.fontBold
                                        }

                                        MouseArea {
                                            id: connectNetworkArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                root.connectWifi(
                                                    modelData
                                                )
                                        }
                                    }

                                    Rectangle {
                                        visible:
                                            modelData.connected

                                        width: 82
                                        height:
                                            root.actionHeight

                                        color:
                                            disconnectNetworkArea.containsMouse
                                                ? ThemeManager.surface
                                                : ThemeManager.backgroundSecondary

                                        Text {
                                            anchors.centerIn: parent

                                            text: "Disconnect"

                                            color:
                                                ThemeManager.textMuted

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize:
                                                ThemeManager.fontTiny + 1
                                        }

                                        MouseArea {
                                            id: disconnectNetworkArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                modelData.disconnect()
                                        }
                                    }

                                    Rectangle {
                                        visible:
                                            modelData.known &&
                                            !modelData.connected

                                        width: 27
                                        height:
                                            root.actionHeight

                                        color:
                                            forgetNetworkArea.containsMouse
                                                ? ThemeManager.danger
                                                : ThemeManager.backgroundSecondary

                                        Text {
                                            anchors.centerIn: parent

                                            text: "×"

                                            color:
                                                forgetNetworkArea.containsMouse
                                                    ? ThemeManager.backgroundSecondary
                                                    : ThemeManager.danger

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize: 16
                                        }

                                        MouseArea {
                                            id: forgetNetworkArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                modelData.forget()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: networkArea

                                    anchors.fill: parent

                                    z: -1

                                    hoverEnabled: true
                                }
                            }
                        }

                        Text {
                            visible:
                                root.wifiDevice &&
                                root.wifiDevice.networks.values.length === 0

                            text: "No networks found."

                            color:
                                ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            Layout.topMargin: 4
                        }
                    }

                    // ───────────────────────────────────────────────
                    // SAVED NETWORKS
                    // ───────────────────────────────────────────────

                    ColumnLayout {
                        visible:
                            root.wifiView === 1

                        Layout.fillWidth: true

                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                width: 28
                                height: 28

                                color:
                                    savedBackArea.containsMouse
                                        ? ThemeManager.surfaceSecondary
                                        : ThemeManager.surface

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰁍"

                                    color:
                                        ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: savedBackArea

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.wifiView = 0
                                }
                            }

                            Text {
                                text: "Saved Networks"

                                color:
                                    ThemeManager.text

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontSmall + 1

                                font.weight:
                                    ThemeManager.fontBold

                                Layout.fillWidth: true
                            }
                        }

                        Repeater {
                            model:
                                savedWifiModel

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true

                                Layout.preferredHeight:
                                    root.networkRowHeight

                                color:
                                    savedNetworkArea.containsMouse
                                        ? ThemeManager.surfaceSecondary
                                        : modelData.connected
                                            ? ThemeManager.surfaceSecondary
                                            : ThemeManager.surface

                                border.width: 1

                                border.color:
                                    modelData.connected
                                        ? ThemeManager.accent
                                        : ThemeManager.surfaceSecondary

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 7

                                    spacing: 8

                                    Text {
                                        text:
                                            root.wifiIcon(
                                                modelData
                                            )

                                        color:
                                            modelData.connected
                                                ? ThemeManager.info
                                                : ThemeManager.textMuted

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text:
                                            modelData.name

                                        color:
                                            ThemeManager.text

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1

                                        Layout.fillWidth: true

                                        elide:
                                            Text.ElideRight
                                    }

                                    Rectangle {
                                        visible:
                                            modelData.connected

                                        width: 82
                                        height:
                                            root.actionHeight

                                        color:
                                            savedDisconnectArea.containsMouse
                                                ? ThemeManager.surface
                                                : ThemeManager.backgroundSecondary

                                        Text {
                                            anchors.centerIn: parent

                                            text: "Disconnect"

                                            color:
                                                ThemeManager.textMuted

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize:
                                                ThemeManager.fontTiny + 1
                                        }

                                        MouseArea {
                                            id: savedDisconnectArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                modelData.disconnect()
                                        }
                                    }

                                    Rectangle {
                                        visible:
                                            !modelData.connected &&
                                            modelData.available !== false

                                        width: 64
                                        height:
                                            root.actionHeight

                                        color:
                                            savedConnectArea.containsMouse
                                                ? ThemeManager.accentDim
                                                : ThemeManager.accent

                                        Text {
                                            anchors.centerIn: parent

                                            text: "Connect"

                                            color:
                                                ThemeManager.background

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize:
                                                ThemeManager.fontTiny + 1

                                            font.weight:
                                                ThemeManager.fontBold
                                        }

                                        MouseArea {
                                            id: savedConnectArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                modelData.connect()
                                        }
                                    }

                                    Rectangle {
                                        width: 27
                                        height:
                                            root.actionHeight

                                        color:
                                            savedForgetArea.containsMouse
                                                ? ThemeManager.danger
                                                : ThemeManager.backgroundSecondary

                                        Text {
                                            anchors.centerIn: parent

                                            text: "×"

                                            color:
                                                savedForgetArea.containsMouse
                                                    ? ThemeManager.backgroundSecondary
                                                    : ThemeManager.danger

                                            font.family:
                                                ThemeManager.fontFamily

                                            font.pixelSize: 16
                                        }

                                        MouseArea {
                                            id: savedForgetArea

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                root.forgetSaved(modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: savedNetworkArea

                                    anchors.fill: parent

                                    z: -1

                                    hoverEnabled: true
                                }
                            }
                        }

                        Text {
                            visible:
                                savedWifiModel.values.length === 0

                            text: "No saved networks."

                            color:
                                ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            Layout.topMargin: 4
                        }
                    }

                    // ───────────────────────────────────────────────
                    // ADD NETWORK
                    // ───────────────────────────────────────────────

                    ColumnLayout {
                        visible:
                            root.wifiView === 2

                        Layout.fillWidth: true

                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                width: 28
                                height: 28

                                color:
                                    addBackArea.containsMouse
                                        ? ThemeManager.surfaceSecondary
                                        : ThemeManager.surface

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰁍"

                                    color:
                                        ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: addBackArea

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.wifiView = 0
                                }
                            }

                            Text {
                                text: "Add Network"

                                color:
                                    ThemeManager.text

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontSmall + 1

                                font.weight:
                                    ThemeManager.fontBold

                                Layout.fillWidth: true
                            }
                        }

                        TextField {
                            id: addNetworkSsidField

                            Layout.fillWidth: true

                            Layout.preferredHeight:
                                root.networkRowHeight

                            placeholderText:
                                "Network name"

                            placeholderTextColor:
                                ThemeManager.textMuted

                            text:
                                root.addNetworkName

                            onTextChanged:
                                root.addNetworkName = text

                            color:
                                ThemeManager.text

                            selectionColor:
                                ThemeManager.accent

                            selectedTextColor:
                                ThemeManager.background

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            leftPadding: 10
                            rightPadding: 10

                            background: Rectangle {
                                color:
                                    ThemeManager.surface

                                border.width: 1

                                border.color:
                                    addNetworkSsidField.activeFocus
                                        ? ThemeManager.accent
                                        : ThemeManager.surfaceSecondary
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true

                            Layout.preferredHeight:
                                root.networkRowHeight

                            color:
                                openNetworkArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                            border.width: 1

                            border.color:
                                ThemeManager.surfaceSecondary

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: "󰖪"

                                    color:
                                        root.addNetworkOpen
                                            ? ThemeManager.accent
                                            : ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 18
                                }

                                Text {
                                    text: "Open network"

                                    color:
                                        ThemeManager.text

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize:
                                        ThemeManager.fontTiny + 1

                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: 38
                                    height: 22

                                    color:
                                        root.addNetworkOpen
                                            ? ThemeManager.accent
                                            : ThemeManager.surfaceSecondary

                                    border.width: 1

                                    border.color:
                                        root.addNetworkOpen
                                            ? ThemeManager.accent
                                            : ThemeManager.overlay

                                    Rectangle {
                                        width: 16
                                        height: 16

                                        anchors.verticalCenter:
                                            parent.verticalCenter

                                        x:
                                            root.addNetworkOpen
                                                ? parent.width - width - 3
                                                : 3

                                        color:
                                            root.addNetworkOpen
                                                ? ThemeManager.background
                                                : ThemeManager.textMuted
                                    }
                                }
                            }

                            MouseArea {
                                id: openNetworkArea

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    root.addNetworkOpen =
                                        !root.addNetworkOpen
                            }
                        }

                        TextField {
                            id: addNetworkPasswordField

                            visible:
                                !root.addNetworkOpen

                            Layout.fillWidth: true

                            Layout.preferredHeight:
                                root.networkRowHeight

                            placeholderText:
                                "Password"

                            placeholderTextColor:
                                ThemeManager.textMuted

                            echoMode:
                                TextInput.Password

                            text:
                                root.addNetworkPassword

                            onTextChanged:
                                root.addNetworkPassword =
                                    text

                            color:
                                ThemeManager.text

                            selectionColor:
                                ThemeManager.accent

                            selectedTextColor:
                                ThemeManager.background

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            leftPadding: 10
                            rightPadding: 10

                            background: Rectangle {
                                color:
                                    ThemeManager.surface

                                border.width: 1

                                border.color:
                                    addNetworkPasswordField.activeFocus
                                        ? ThemeManager.accent
                                        : ThemeManager.surfaceSecondary
                            }

                            Keys.onReturnPressed:
                                root.addNetwork()
                        }

                        Rectangle {
                            Layout.fillWidth: true

                            Layout.preferredHeight:
                                root.actionHeight

                            color:
                                addNetworkButtonArea.containsMouse
                                    ? ThemeManager.accentDim
                                    : ThemeManager.accent

                            Text {
                                anchors.centerIn: parent

                                text: "Add Network"

                                color:
                                    ThemeManager.background

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontTiny + 1

                                font.weight:
                                    ThemeManager.fontBold
                            }

                            MouseArea {
                                id: addNetworkButtonArea

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    root.addNetwork()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // BLUETOOTH EXPANDED
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            visible:
                root.bluetoothExpanded

            Layout.fillWidth: true

            implicitHeight:
                Math.min(
                    root.expandedContentCap,
                    bluetoothColumn.implicitHeight
                ) + 20

            radius: 0

            color:
                ThemeManager.backgroundSecondary

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            Flickable {
                id: bluetoothScroller

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }

                anchors.margins: 10

                clip: true

                contentWidth: width
                contentHeight:
                    bluetoothColumn.implicitHeight

                interactive:
                    contentHeight > height

                ColumnLayout {
                    id: bluetoothColumn

                    width:
                        bluetoothScroller.width

                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Bluetooth Devices"

                            color:
                                ThemeManager.text

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontSmall + 1

                            font.weight:
                                ThemeManager.fontBold

                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 28
                            height: 28

                            color:
                                bluetoothRefreshArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                            Text {
                                anchors.centerIn: parent

                                text: "󰑐"

                                color:
                                    root.bluetoothAdapter &&
                                    root.bluetoothAdapter.discovering
                                        ? ThemeManager.accent
                                        : ThemeManager.textMuted

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: bluetoothRefreshArea

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    if (root.bluetoothAdapter)
                                        root.bluetoothAdapter.discovering =
                                            !root.bluetoothAdapter.discovering
                                }
                            }
                        }
                    }

                    Text {
                        visible:
                            !root.bluetoothAdapter ||
                            !root.bluetoothAdapter.enabled

                        text:
                            "Bluetooth is disabled."

                        color:
                            ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontTiny + 1
                    }

                    Repeater {
                        model:
                            root.bluetoothAdapter
                                ? root.bluetoothAdapter.devices
                                : null

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true

                            Layout.preferredHeight:
                                root.networkRowHeight + 6

                            color:
                                bluetoothDeviceArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : modelData.connected
                                        ? ThemeManager.surfaceSecondary
                                        : ThemeManager.surface

                            border.width: 1

                            border.color:
                                modelData.connected
                                    ? ThemeManager.accent
                                    : ThemeManager.surfaceSecondary

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 9
                                anchors.rightMargin: 7

                                spacing: 8

                                Text {
                                    text: "󰂯"

                                    color:
                                        modelData.connected
                                            ? ThemeManager.info
                                            : ThemeManager.textMuted

                                    font.family:
                                        ThemeManager.fontFamily

                                    font.pixelSize: 19
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    spacing: 1

                                    Text {
                                        text:
                                            modelData.name ||
                                            modelData.deviceName ||
                                            "Unknown device"

                                        color:
                                            ThemeManager.text

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1

                                        Layout.fillWidth: true

                                        elide:
                                            Text.ElideRight
                                    }

                                    Text {
                                        text: {
                                            if (modelData.pairing)
                                                return "Pairing…"

                                            if (modelData.connected)
                                                return "Connected"

                                            if (modelData.paired)
                                                return "Saved"

                                            return "Available"
                                        }

                                        color:
                                            modelData.connected
                                                ? ThemeManager.success
                                                : ThemeManager.textMuted

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1
                                    }
                                }

                                Rectangle {
                                    visible:
                                        !modelData.paired &&
                                        !modelData.pairing

                                    width: 64

                                    height:
                                        root.actionHeight

                                    color:
                                        bluetoothPairArea.containsMouse
                                            ? ThemeManager.accentDim
                                            : ThemeManager.accent

                                    Text {
                                        anchors.centerIn: parent

                                        text: "Pair"

                                        color:
                                            ThemeManager.background

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1

                                        font.weight:
                                            ThemeManager.fontBold
                                    }

                                    MouseArea {
                                        id: bluetoothPairArea

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            modelData.pair()
                                    }
                                }

                                Rectangle {
                                    visible:
                                        modelData.paired &&
                                        !modelData.connected

                                    width: 64

                                    height:
                                        root.actionHeight

                                    color:
                                        bluetoothConnectArea.containsMouse
                                            ? ThemeManager.accentDim
                                            : ThemeManager.accent

                                    Text {
                                        anchors.centerIn: parent

                                        text: "Connect"

                                        color:
                                            ThemeManager.background

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1

                                        font.weight:
                                            ThemeManager.fontBold
                                    }

                                    MouseArea {
                                        id: bluetoothConnectArea

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            modelData.connect()
                                    }
                                }

                                Rectangle {
                                    visible:
                                        modelData.connected

                                    width: 82

                                    height:
                                        root.actionHeight

                                    color:
                                        bluetoothDisconnectArea.containsMouse
                                            ? ThemeManager.surface
                                            : ThemeManager.backgroundSecondary

                                    Text {
                                        anchors.centerIn: parent

                                        text: "Disconnect"

                                        color:
                                            ThemeManager.textMuted

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize:
                                            ThemeManager.fontTiny + 1
                                    }

                                    MouseArea {
                                        id: bluetoothDisconnectArea

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            modelData.disconnect()
                                    }
                                }

                                Rectangle {
                                    visible:
                                        modelData.paired

                                    width: 27

                                    height:
                                        root.actionHeight

                                    color:
                                        bluetoothForgetArea.containsMouse
                                            ? ThemeManager.danger
                                            : ThemeManager.backgroundSecondary

                                    Text {
                                        anchors.centerIn: parent

                                        text: "×"

                                        color:
                                            bluetoothForgetArea.containsMouse
                                                ? ThemeManager.backgroundSecondary
                                                : ThemeManager.danger

                                        font.family:
                                            ThemeManager.fontFamily

                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: bluetoothForgetArea

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            modelData.forget()
                                    }
                                }
                            }

                            MouseArea {
                                id: bluetoothDeviceArea

                                anchors.fill: parent

                                z: -1

                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // AIRPLANE + NIGHT MODE
        // ═══════════════════════════════════════════════════════════

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            // ───────────────────────────────────────────────────────
            // AIRPLANE MODE
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon: "󰀝"

                label: "Airplane Mode"

                checked: root.airplaneMode

                activate:
                    () => root.toggleAirplane()
            }

            // ───────────────────────────────────────────────────────
            // NIGHT MODE (hyprsunset)
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon: "󰖔"

                label: "Night Mode"

                checked: root.nightMode

                activeColor:
                    ThemeManager.warning

                activate:
                    () => root.toggleNightMode()
            }
        }

        // ═══════════════════════════════════════════════════════════
        // POWER PROFILES + IDLE INHIBIT
        // ═══════════════════════════════════════════════════════════

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            // ───────────────────────────────────────────────────────
            // POWER PROFILES
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon:
                    root.powerProfileIcon(
                        PowerProfiles.profile
                    )

                label:
                    root.powerProfileName(
                        PowerProfiles.profile
                    )

                iconColorUnchecked:
                    root.powerProfileColor(
                        PowerProfiles.profile
                    )

                activate:
                    () => root.cyclePowerProfile()
            }

            // ───────────────────────────────────────────────────────
            // IDLE INHIBIT (hypridle)
            // ───────────────────────────────────────────────────────

            ToggleTile {
                icon: "󰅶"

                label: "Idle Inhibit"

                checked: root.idleInhibited

                activate:
                    () => root.toggleIdleInhibit()
            }
        }

        // ═══════════════════════════════════════════════════════════
        // VOLUME
        // ═══════════════════════════════════════════════════════════

        SliderRow {
            icon: root.volumeIcon()

            iconColor:
                root.audioSink &&
                root.audioSink.audio &&
                !root.audioSink.audio.muted
                    ? ThemeManager.accent
                    : ThemeManager.textMuted

            iconClickable: true

            onIconClicked: () => {
                if (
                    root.audioSink &&
                    root.audioSink.audio
                ) {
                    root.audioSink.audio.muted =
                        !root.audioSink.audio.muted
                }
            }

            fillColor:
                ThemeManager.accent

            from: 0
            to: 1

            value:
                root.audioSink &&
                root.audioSink.audio
                    ? root.audioSink.audio.volume
                    : 0

            onMoved: (v) => {
                if (
                    root.audioSink &&
                    root.audioSink.audio
                ) {
                    root.audioSink.audio.volume = v
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // BRIGHTNESS
        // ═══════════════════════════════════════════════════════════

        SliderRow {
            icon: root.brightnessIcon()

            iconColor:
                ThemeManager.warning

            fillColor:
                ThemeManager.warning

            from: 1
            to: 100

            value: root.brightness

            onMoved: (v) => {
                root.brightness = Math.round(v)

                brightnessWrite.command = [
                    "brightnessctl",
                    "set",
                    root.brightness + "%"
                ]

                brightnessWrite.running = true
            }
        }

        // ═══════════════════════════════════════════════════════════
        // WARMNESS (night mode)
        // ═══════════════════════════════════════════════════════════

        SliderRow {
            icon: "󰔏"

            iconColor:
                ThemeManager.warning

            fillColor:
                ThemeManager.warning

            // NOTE: from/to are reversed on purpose so dragging right
            // moves toward warmer (lower Kelvin) — matches the visual
            // direction most people expect for a "warmth" slider.
            from: 6500
            to: 1000
            stepSize: 100

            // While pressed, follow the live drag position instead of
            // the bound value — otherwise the 100K-rounded write-back
            // in setNightTemperature() fights the drag every frame.
            liveWhilePressed: true

            value: root.nightTemperature

            onMoved: (v) =>
                root.setNightTemperature(v)

            visible: root.nightMode
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WIFI PASSWORD DIALOG
    // ═══════════════════════════════════════════════════════════════

    Rectangle {
        id: passwordDialog

        anchors.centerIn: mainColumn

        width: 340
        height: 180

        visible: false

        z: 100

        color:
            ThemeManager.background

        border.width: 1

        border.color:
            ThemeManager.surfaceSecondary

        MouseArea {
            anchors.fill: parent

            hoverEnabled: true

            onClicked: {
                // Consume click.
            }
        }

        ColumnLayout {
            anchors.fill: parent

            anchors.margins: 16

            spacing: 10

            Text {
                text: "Connect to Wi-Fi"

                color:
                    ThemeManager.text

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontNormal

                font.weight:
                    ThemeManager.fontBold
            }

            Text {
                text:
                    root.selectedWifi
                        ? root.selectedWifi.name
                        : ""

                color:
                    ThemeManager.accent

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontTiny + 1

                Layout.fillWidth: true

                elide:
                    Text.ElideRight
            }

            TextField {
                id: passwordField

                Layout.fillWidth: true

                Layout.preferredHeight:
                    root.networkRowHeight

                placeholderText:
                    "Password"

                placeholderTextColor:
                    ThemeManager.textMuted

                echoMode:
                    TextInput.Password

                text:
                    root.wifiPassword

                onTextChanged:
                    root.wifiPassword =
                        text

                color:
                    ThemeManager.text

                selectionColor:
                    ThemeManager.accent

                selectedTextColor:
                    ThemeManager.background

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontTiny + 1

                leftPadding: 10
                rightPadding: 10

                background: Rectangle {
                    radius: 0

                    color:
                        ThemeManager.surface

                    border.width: 1

                    border.color:
                        passwordField.activeFocus
                            ? ThemeManager.accent
                            : ThemeManager.surfaceSecondary
                }

                Keys.onReturnPressed:
                    root.connectWifiPassword()

                Keys.onEscapePressed: {
                    root.cancelWifiPassword()
                    event.accepted = true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 70

                    height:
                        root.actionHeight

                    color:
                        passwordCancelArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface

                    Text {
                        anchors.centerIn: parent

                        text: "Cancel"

                        color:
                            ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontTiny + 1
                    }

                    MouseArea {
                        id: passwordCancelArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.cancelWifiPassword()
                    }
                }

                Rectangle {
                    width: 75

                    height:
                        root.actionHeight

                    color:
                        passwordConnectArea.containsMouse
                            ? ThemeManager.accentDim
                            : ThemeManager.accent

                    Text {
                        anchors.centerIn: parent

                        text: "Connect"

                        color:
                            ThemeManager.background

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontTiny + 1

                        font.weight:
                            ThemeManager.fontBold
                    }

                    MouseArea {
                        id: passwordConnectArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.connectWifiPassword()
                    }
                }
            }
        }
    }
}
