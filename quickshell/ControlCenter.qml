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
import "./services"

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    margins {
        top: 38
        right: 4
    }

    implicitWidth: 430
    implicitHeight: mainColumn.implicitHeight + 32

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    readonly property int tileHeight: 58
    readonly property int networkRowHeight: 46
    readonly property int actionHeight: 26

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

    ScriptModel {
        id: savedWifiModel

        values:
            root.wifiDevice
                ? [...root.wifiDevice.networks.values]
                    .filter(network => network.known)
                    .sort(
                        (a, b) => {
                            if (a.connected !== b.connected)
                                return a.connected ? -1 : 1

                            return root.wifiSignal(b) -
                                   root.wifiSignal(a)
                        }
                    )
                : []
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

    function toggleAirplane() {
        airplaneProcess.running = true
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
            }
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
                 * enabled  enabled enabled  enabled
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
        brightnessRead.running = true
        airplaneRead.running = true

        if (wifiDevice)
            wifiDevice.scannerEnabled = true

        keyboardFocus.forceActiveFocus()
        focusGrab.active = true
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
    // BACKGROUND
    // ═══════════════════════════════════════════════════════════════

    Rectangle {
        anchors.fill: parent

        radius: 0

        color:
            ThemeManager.backgroundDeep

        border.width: 2

        border.color:
            ThemeManager.accent
    }

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

            // ═══════════════════════════════════════════════════════
            // WIFI
            // ═══════════════════════════════════════════════════════

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.tileHeight

                radius: 0

                color:
                    Networking.wifiEnabled
                        ? ThemeManager.accent
                        : wifiToggleArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface

                border.width: 1

                border.color:
                    root.wifiExpanded
                        ? ThemeManager.accent
                        : ThemeManager.surfaceSecondary

                // Main toggle area
                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width * 0.75

                    color:
                        Networking.wifiEnabled
                            ? ThemeManager.accent
                            : wifiToggleArea.containsMouse
                                ? ThemeManager.surfaceSecondary
                                : ThemeManager.surface

                    MouseArea {
                        id: wifiToggleArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.toggleWifi()
                    }

                    RowLayout {
                        anchors.fill: parent

                        anchors.margins: 11

                        spacing: 8

                        Text {
                            text:
                                root.wifiTileIcon()

                            color:
                                Networking.wifiEnabled
                                    ? ThemeManager.background
                                    : ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize: 22
                        }

                        Text {
                            text:
                                root.connectedWifi
                                    ? root.connectedWifi.name
                                    : "Wi-Fi"

                            color:
                                Networking.wifiEnabled
                                    ? ThemeManager.background
                                    : ThemeManager.text

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontSmall + 1

                            font.weight:
                                Networking.wifiEnabled
                                    ? ThemeManager.fontBold
                                    : Font.Normal

                            Layout.fillWidth: true

                            elide:
                                Text.ElideRight
                        }
                    }
                }

                // Expand area
                Rectangle {
                    anchors {
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width * 0.25

                    // IMPORTANT:
                    // This area NEVER becomes accent when expanded.
                    // It only gets the normal hover highlight.
                    color:
                        wifiExpandArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface
                    border.width:
                                Networking.wifiEnabled
                                    ? 2
                                    : 0
                    border.color: ThemeManager.accent
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }

                        width: 1

                        color: Networking.wifiEnabled
                            ? ThemeManager.accent
                            : ThemeManager.surfaceSecondary
                    }

                    MouseArea {
                        id: wifiExpandArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.wifiExpanded =
                                !root.wifiExpanded

                            root.bluetoothExpanded =
                                false

                            if (root.wifiDevice)
                                root.wifiDevice.scannerEnabled =
                                    root.wifiExpanded
                        }
                    }

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.wifiExpanded
                                ? "󰅃"
                                : "󰅀"

                        // ONLY THE POINTER becomes accent
                        // when expanded.
                        color:
                            root.wifiExpanded
                                ? ThemeManager.accent
                                : ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize: 18
                    }
                }
            }

            // ═══════════════════════════════════════════════════════
            // BLUETOOTH
            // ═══════════════════════════════════════════════════════

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.tileHeight

                radius: 0

                color:
                    root.bluetoothAdapter &&
                    root.bluetoothAdapter.enabled
                        ? ThemeManager.accent
                        : bluetoothToggleArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface

                border.width: 1

                border.color:
                    root.bluetoothExpanded
                        ? ThemeManager.accent
                        : ThemeManager.surfaceSecondary

                // Main toggle area
                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width * 0.75

                    color:
                        root.bluetoothAdapter &&
                        root.bluetoothAdapter.enabled
                            ? ThemeManager.accent
                            : bluetoothToggleArea.containsMouse
                                ? ThemeManager.surfaceSecondary
                                : ThemeManager.surface

                    MouseArea {
                        id: bluetoothToggleArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.toggleBluetooth()
                    }

                    RowLayout {
                        anchors.fill: parent

                        anchors.margins: 11

                        spacing: 8

                        Text {
                            text:
                                root.bluetoothIcon()

                            color:
                                root.bluetoothAdapter &&
                                root.bluetoothAdapter.enabled
                                    ? ThemeManager.background
                                    : ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize: 22
                        }

                        Text {
                            text: "Bluetooth"

                            color:
                                root.bluetoothAdapter &&
                                root.bluetoothAdapter.enabled
                                    ? ThemeManager.background
                                    : ThemeManager.text

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontSmall + 1

                            font.weight:
                                root.bluetoothAdapter &&
                                root.bluetoothAdapter.enabled
                                    ? ThemeManager.fontBold
                                    : Font.Normal

                            Layout.fillWidth: true
                        }
                    }
                }

                // Expand area
                Rectangle {
                    anchors {
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width * 0.25

                    color:
                        bluetoothExpandArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface
                    border.width:
                        root.bluetoothAdapter &&
                        root.bluetoothAdapter.enabled
                            ? 2
                            : 0
                    border.color: ThemeManager.accent
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }

                        width:
                        root.bluetoothAdapter &&
                        root.bluetoothAdapter.enabled
                            ? 0
                            : 1
                        color:
                            ThemeManager.surfaceSecondary
                    }

                    MouseArea {
                        id: bluetoothExpandArea

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.bluetoothExpanded =
                                !root.bluetoothExpanded

                            root.wifiExpanded =
                                false

                            if (root.bluetoothAdapter)
                                root.bluetoothAdapter.discovering =
                                    root.bluetoothExpanded
                        }
                    }

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.bluetoothExpanded
                                ? "󰅃"
                                : "󰅀"

                        // ONLY THE POINTER becomes accent
                        // when expanded.
                        color:
                            root.bluetoothExpanded
                                ? ThemeManager.accent
                                : ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize: 18
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // WIFI EXPANDED
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            visible:
                root.wifiExpanded

            Layout.fillWidth: true

            implicitHeight:
                wifiColumn.implicitHeight + 20

            radius: 0

            color:
                ThemeManager.background

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            ColumnLayout {
                id: wifiColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }

                anchors.margins: 10

                spacing: 6

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
                                        root.isOpenWifi(modelData)
                                            ? ""
                                            : "󰌾"

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

                // ═══════════════════════════════════════════════════
                // SAVED NETWORKS
                // ═══════════════════════════════════════════════════

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
                                        !modelData.connected

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
                                            modelData.forget()
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

                // ═══════════════════════════════════════════════════
                // ADD NETWORK
                // ═══════════════════════════════════════════════════

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

        // ═══════════════════════════════════════════════════════════
        // BLUETOOTH EXPANDED
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            visible:
                root.bluetoothExpanded

            Layout.fillWidth: true

            implicitHeight:
                bluetoothColumn.implicitHeight + 20

            radius: 0

            color:
                ThemeManager.backgroundSecondary

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            ColumnLayout {
                id: bluetoothColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }

                anchors.margins: 10

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

        // ═══════════════════════════════════════════════════════════
        // AIRPLANE + POWER PROFILES
        // ═══════════════════════════════════════════════════════════

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            // ═══════════════════════════════════════════════════════
            // AIRPLANE MODE
            // ═══════════════════════════════════════════════════════

            Rectangle {
                Layout.fillWidth: true

                Layout.preferredHeight:
                    root.tileHeight

                color:
                    root.airplaneMode
                        ? ThemeManager.accent
                        : airplaneArea.containsMouse
                            ? ThemeManager.surfaceSecondary
                            : ThemeManager.surface

                border.width: 1

                border.color:
                    root.airplaneMode
                        ? ThemeManager.accent
                        : ThemeManager.surfaceSecondary

                RowLayout {
                    anchors.fill: parent

                    anchors.margins: 11

                    spacing: 8

                    Text {
                        text: "󰀝"

                        color:
                            root.airplaneMode
                                ? ThemeManager.background
                                : ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize: 20
                    }

                    Text {
                        text: "Airplane Mode"

                        color:
                            root.airplaneMode
                                ? ThemeManager.background
                                : ThemeManager.text

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontTiny + 1

                        font.weight:
                            root.airplaneMode
                                ? ThemeManager.fontBold
                                : Font.Normal

                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: airplaneArea

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked:
                        root.toggleAirplane()
                }
            }

            // ═══════════════════════════════════════════════════════
            // POWER PROFILES
            // ═══════════════════════════════════════════════════════

            Rectangle {
                Layout.fillWidth: true

                Layout.preferredHeight:
                    root.tileHeight

                color:
                    ThemeManager.surface

                border.width: 1

                border.color:
                    ThemeManager.surfaceSecondary

                RowLayout {
                    anchors.fill: parent

                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        color:
                            PowerProfiles.profile ===
                            PowerProfile.PowerSaver
                                ? ThemeManager.success
                                : stealthArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                        Text {
                            anchors.centerIn: parent

                            text: "Stealth"

                            color:
                                PowerProfiles.profile ===
                                PowerProfile.PowerSaver
                                    ? ThemeManager.background
                                    : ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            font.weight:
                                PowerProfiles.profile ===
                                PowerProfile.PowerSaver
                                    ? ThemeManager.fontBold
                                    : Font.Normal
                        }

                        MouseArea {
                            id: stealthArea

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                PowerProfiles.profile =
                                    PowerProfile.PowerSaver

                                keyboardFocus.forceActiveFocus()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        color:
                            PowerProfiles.profile ===
                            PowerProfile.Balanced
                                ? ThemeManager.accent
                                : steadyArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                        Text {
                            anchors.centerIn: parent

                            text: "Steady"

                            color:
                                PowerProfiles.profile ===
                                PowerProfile.Balanced
                                    ? ThemeManager.background
                                    : ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            font.weight:
                                PowerProfiles.profile ===
                                PowerProfile.Balanced
                                    ? ThemeManager.fontBold
                                    : Font.Normal
                        }

                        MouseArea {
                            id: steadyArea

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                PowerProfiles.profile =
                                    PowerProfile.Balanced

                                keyboardFocus.forceActiveFocus()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        color:
                            PowerProfiles.profile ===
                            PowerProfile.Performance
                                ? ThemeManager.danger
                                : strideArea.containsMouse
                                    ? ThemeManager.surfaceSecondary
                                    : ThemeManager.surface

                        Text {
                            anchors.centerIn: parent

                            text: "Stride"

                            color:
                                PowerProfiles.profile ===
                                PowerProfile.Performance
                                    ? ThemeManager.background
                                    : ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTiny + 1

                            font.weight:
                                PowerProfiles.profile ===
                                PowerProfile.Performance
                                    ? ThemeManager.fontBold
                                    : Font.Normal
                        }

                        MouseArea {
                            id: strideArea

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                PowerProfiles.profile =
                                    PowerProfile.Performance

                                keyboardFocus.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // VOLUME
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight:
                root.tileHeight

            radius: 0

            color:
                ThemeManager.surface

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            RowLayout {
                anchors.fill: parent

                anchors.leftMargin: 12
                anchors.rightMargin: 12

                spacing: 10

                MouseArea {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        if (
                            root.audioSink &&
                            root.audioSink.audio
                        ) {
                            root.audioSink.audio.muted =
                                !root.audioSink.audio.muted
                        }
                    }

                    Text {
                        anchors.centerIn: parent

                        text:
                            root.volumeIcon()

                        color:
                            root.audioSink &&
                            root.audioSink.audio &&
                            !root.audioSink.audio.muted
                                ? ThemeManager.accent
                                : ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize: 21
                    }
                }

                Slider {
                    id: volumeSlider

                    Layout.fillWidth: true

                    Layout.preferredHeight: 26

                    from: 0
                    to: 1

                    value:
                        root.audioSink &&
                        root.audioSink.audio
                            ? root.audioSink.audio.volume
                            : 0

                    onMoved: {
                        if (
                            root.audioSink &&
                            root.audioSink.audio
                        ) {
                            root.audioSink.audio.volume =
                                value
                        }
                    }

                    background: Rectangle {
                        x:
                            volumeSlider.leftPadding

                        y:
                            volumeSlider.topPadding +
                            volumeSlider.availableHeight / 2 -
                            height / 2

                        implicitWidth: 200
                        implicitHeight: 4

                        width:
                            volumeSlider.availableWidth

                        height:
                            implicitHeight

                        radius: 0

                        color:
                            ThemeManager.surfaceSecondary

                        Rectangle {
                            width:
                                volumeSlider.visualPosition *
                                parent.width

                            height:
                                parent.height

                            color:
                                ThemeManager.accent
                        }
                    }

                    handle: Rectangle {
                        x:
                            volumeSlider.leftPadding +
                            volumeSlider.visualPosition *
                            (
                                volumeSlider.availableWidth -
                                width
                            )

                        y:
                            volumeSlider.topPadding +
                            volumeSlider.availableHeight / 2 -
                            height / 2

                        implicitWidth: 14
                        implicitHeight: 14

                        width:
                            implicitWidth

                        height:
                            implicitHeight

                        radius: 7

                        color:
                            ThemeManager.accent
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════
        // BRIGHTNESS
        // ═══════════════════════════════════════════════════════════

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight:
                root.tileHeight

            radius: 0

            color:
                ThemeManager.surface

            border.width: 1

            border.color:
                ThemeManager.surfaceSecondary

            RowLayout {
                anchors.fill: parent

                anchors.leftMargin: 12
                anchors.rightMargin: 12

                spacing: 10

                Text {
                    text:
                        root.brightnessIcon()

                    color:
                        ThemeManager.warning

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize: 21

                    Layout.preferredWidth: 26

                    horizontalAlignment:
                        Text.AlignHCenter
                }

                Slider {
                    id: brightnessSlider

                    Layout.fillWidth: true

                    Layout.preferredHeight: 26

                    from: 1
                    to: 100

                    value:
                        root.brightness

                    onMoved: {
                        root.brightness =
                            Math.round(value)

                        brightnessWrite.command = [
                            "brightnessctl",
                            "set",
                            root.brightness + "%"
                        ]

                        brightnessWrite.running =
                            true
                    }

                    background: Rectangle {
                        x:
                            brightnessSlider.leftPadding

                        y:
                            brightnessSlider.topPadding +
                            brightnessSlider.availableHeight / 2 -
                            height / 2

                        implicitWidth: 200
                        implicitHeight: 4

                        width:
                            brightnessSlider.availableWidth

                        height:
                            implicitHeight

                        radius: 0

                        color:
                            ThemeManager.surfaceSecondary

                        Rectangle {
                            width:
                                brightnessSlider.visualPosition *
                                parent.width

                            height:
                                parent.height

                            color:
                                ThemeManager.accent
                        }
                    }

                    handle: Rectangle {
                        x:
                            brightnessSlider.leftPadding +
                            brightnessSlider.visualPosition *
                            (
                                brightnessSlider.availableWidth -
                                width
                            )

                        y:
                            brightnessSlider.topPadding +
                            brightnessSlider.availableHeight / 2 -
                            height / 2

                        implicitWidth: 14
                        implicitHeight: 14

                        width:
                            implicitWidth

                        height:
                            implicitHeight

                        radius: 7

                        color:
                            ThemeManager.accent
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WIFI PASSWORD DIALOG
    // ═══════════════════════════════════════════════════════════════

    Rectangle {
        id: passwordDialog

        anchors.centerIn: parent

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
