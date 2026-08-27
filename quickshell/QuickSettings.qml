import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Io

PopupWindow {
    id: popup

    property var barWindow: null

    property bool wifiExpanded: false
    property bool bluetoothExpanded: false

    property var wifiDevice: Networking.devices.values.find(
        device => device.type === DeviceType.Wifi
    )

    property var bluetoothAdapter: Bluetooth.defaultAdapter

    property var connectedWifi: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected)
        : null

    property var connectedBluetooth: bluetoothAdapter
        ? bluetoothAdapter.devices.values.filter(device => device.connected)
        : []

    property var audioSink: Pipewire.defaultAudioSink

    property string pendingWifiName: ""
    property var pendingWifiNetwork: null

    property int brightness: 50
    property bool airplaneMode: false

    visible: false
    grabFocus: true

    width: 420

    height: contentColumn.implicitHeight + 32

    color: "transparent"

    anchor.window: barWindow

    anchor.rect.x: barWindow
        ? barWindow.width - width - 12
        : 0

    anchor.rect.y: barWindow
        ? barWindow.height + 8
        : 0

    function open() {
        wifiExpanded = false
        bluetoothExpanded = false
        visible = true

        brightnessReader.running = true
    }

    function close() {
        visible = false
        pendingWifiNetwork = null
        pendingWifiName = ""
    }

    function toggle() {
        if (visible)
            close()
        else
            open()
    }

    function run(command) {
        Quickshell.execDetached(command)
    }

    function toggleAirplane() {
        airplaneMode = !airplaneMode

        if (airplaneMode) {
            run(["nmcli", "radio", "all", "off"])
            run(["rfkill", "block", "all"])
        } else {
            run(["rfkill", "unblock", "all"])
            run(["nmcli", "radio", "all", "on"])
        }
    }

    function changeBrightness(value) {
        brightness = Math.round(value)

        brightnessProcess.command = [
            "brightnessctl",
            "set",
            brightness + "%"
        ]

        brightnessProcess.running = true
    }

    function connectWifi(network) {
        if (!network)
            return

        if (network.known) {
            network.connect()
            return
        }

        pendingWifiNetwork = network
        pendingWifiName = network.name
        passwordDialog.open()
    }

    function connectWifiWithPassword(password) {
        if (!pendingWifiNetwork)
            return

        pendingWifiNetwork.connectWithPsk(password)

        pendingWifiNetwork = null
        pendingWifiName = ""
    }

    function wifiSignal(network) {
        if (!network)
            return 0

        if (network.signalStrength !== undefined)
            return Math.round(network.signalStrength * 100)

        return 0
    }

    function wifiIcon(network) {
        if (!network)
            return "󰤯"

        let strength = wifiSignal(network)

        if (strength >= 75)
            return "󰤨"

        if (strength >= 50)
            return "󰤥"

        if (strength >= 25)
            return "󰤢"

        return "󰤟"
    }

    function bluetoothIcon(device) {
        if (!device)
            return "󰂯"

        return device.icon || "󰂯"
    }

    function powerProfileName() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return "Stride"

        case PowerProfile.PowerSaver:
            return "Stealth"

        default:
            return "Steady"
        }
    }

    function powerProfileIcon() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return "󰓅"

        case PowerProfile.PowerSaver:
            return "󰾆"

        default:
            return "󰗑"
        }
    }

    Connections {
        target: popup

        function onVisibleChanged() {
            if (!popup.visible) {
                passwordField.text = ""
            }
        }
    }

    Process {
        id: brightnessProcess
    }

    Process {
        id: brightnessReader

        command: [
            "brightnessctl",
            "-m"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let output = this.text.trim()

                if (!output)
                    return

                let parts = output.split(",")

                if (parts.length >= 4) {
                    let current = parseInt(
                        parts[3].replace("%", "")
                    )

                    if (!isNaN(current))
                        popup.brightness = current
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: popup.visible
        repeat: true

        onTriggered: {
            brightnessReader.running = true

            if (wifiDevice)
                wifiDevice.scannerEnabled = true
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: 14

        color: Colors.base

        border.width: 1
        border.color: Colors.surface1

        opacity: 0.99
    }

    ColumnLayout {
        id: contentColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top

            leftMargin: 16
            rightMargin: 16
            topMargin: 16
            bottomMargin: 16
        }

        spacing: 10

        // ─────────────────────────────────────────────────────────────
        // Header
        // ─────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Quick Settings"

                color: Colors.text

                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                font.weight: Font.Bold

                Layout.fillWidth: true
            }

            MouseArea {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                onClicked: popup.close()

                Text {
                    anchors.centerIn: parent

                    text: "×"

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Primary toggles
        // ─────────────────────────────────────────────────────────────

        GridLayout {
            columns: 2

            Layout.fillWidth: true

            columnSpacing: 8
            rowSpacing: 8

            // Wi-Fi
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72

                radius: 10

                color: wifiDevice && wifiDevice.connected
                    ? Colors.surface1
                    : Colors.surface0

                border.width: 1
                border.color: wifiExpanded
                    ? Colors.lavender
                    : Colors.surface1

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        wifiExpanded = !wifiExpanded
                        bluetoothExpanded = false

                        if (wifiDevice)
                            wifiDevice.scannerEnabled = wifiExpanded
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }

                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "󰤨"

                            color: wifiDevice && wifiDevice.connected
                                ? Colors.blue
                                : Colors.subtext0

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                        }

                        Text {
                            text: "Wi-Fi"

                            color: Colors.text

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold

                            Layout.fillWidth: true
                        }

                        Text {
                            text: wifiExpanded ? "⌃" : "⌄"

                            color: Colors.subtext0

                            font.pixelSize: 16
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        text: {
                            if (!wifiDevice)
                                return "Unavailable"

                            if (!wifiDevice.connected)
                                return "Disconnected"

                            return connectedWifi
                                ? connectedWifi.name
                                : "Connected"
                        }

                        color: Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11

                        elide: Text.ElideRight
                    }
                }
            }

            // Bluetooth
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72

                radius: 10

                color: bluetoothAdapter && bluetoothAdapter.enabled
                    ? Colors.surface1
                    : Colors.surface0

                border.width: 1
                border.color: bluetoothExpanded
                    ? Colors.lavender
                    : Colors.surface1

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        bluetoothExpanded = !bluetoothExpanded
                        wifiExpanded = false

                        if (bluetoothAdapter)
                            bluetoothAdapter.discovering = bluetoothExpanded
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }

                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "󰂯"

                            color: bluetoothAdapter && bluetoothAdapter.enabled
                                ? Colors.blue
                                : Colors.subtext0

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                        }

                        Text {
                            text: "Bluetooth"

                            color: Colors.text

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold

                            Layout.fillWidth: true
                        }

                        Text {
                            text: bluetoothExpanded ? "⌃" : "⌄"

                            color: Colors.subtext0

                            font.pixelSize: 16
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        text: {
                            if (!bluetoothAdapter)
                                return "Unavailable"

                            if (!bluetoothAdapter.enabled)
                                return "Disabled"

                            if (connectedBluetooth.length === 0)
                                return "Not connected"

                            return connectedBluetooth.length === 1
                                ? connectedBluetooth[0].name
                                : connectedBluetooth.length + " connected"
                        }

                        color: Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11

                        elide: Text.ElideRight
                    }
                }
            }

            // Airplane mode
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                radius: 10

                color: airplaneMode
                    ? Colors.surface1
                    : Colors.surface0

                border.width: 1
                border.color: airplaneMode
                    ? Colors.lavender
                    : Colors.surface1

                MouseArea {
                    anchors.fill: parent

                    onClicked: popup.toggleAirplane()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    Text {
                        text: "󰀝"

                        color: airplaneMode
                            ? Colors.lavender
                            : Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 21
                    }

                    Text {
                        text: "Airplane Mode"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12

                        Layout.fillWidth: true
                    }

                    Text {
                        text: airplaneMode ? "ON" : "OFF"

                        color: airplaneMode
                            ? Colors.lavender
                            : Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
            }

            // Power profile
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                radius: 10

                color: Colors.surface0

                border.width: 1
                border.color: Colors.surface1

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (!PowerProfiles.hasPerformanceProfile) {
                            PowerProfiles.profile =
                                PowerProfiles.profile === PowerProfile.PowerSaver
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
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    Text {
                        text: popup.powerProfileIcon()

                        color: {
                            switch (PowerProfiles.profile) {
                            case PowerProfile.Performance:
                                return Colors.red

                            case PowerProfile.PowerSaver:
                                return Colors.green

                            default:
                                return Colors.lavender
                            }
                        }

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                    }

                    Text {
                        text: "Power"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12

                        Layout.fillWidth: true
                    }

                    Text {
                        text: popup.powerProfileName()

                        color: Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Wi-Fi expanded section
        // ─────────────────────────────────────────────────────────────

        Rectangle {
            visible: wifiExpanded

            Layout.fillWidth: true

            implicitHeight: wifiColumn.implicitHeight + 20

            radius: 10

            color: Colors.mantle

            border.width: 1
            border.color: Colors.surface1

            ColumnLayout {
                id: wifiColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top

                    margins: 10
                }

                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Networks"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold

                        Layout.fillWidth: true
                    }

                    MouseArea {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        onClicked: {
                            if (wifiDevice)
                                wifiDevice.scannerEnabled = true
                        }

                        Text {
                            anchors.centerIn: parent

                            text: wifiDevice && wifiDevice.scannerEnabled
                                ? "󰑐"
                                : "󰑐"

                            color: Colors.subtext0

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                        }
                    }
                }

                Text {
                    visible: !wifiDevice

                    text: "No Wi-Fi adapter found."

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Text {
                    visible: wifiDevice &&
                             wifiDevice.networks.values.length === 0

                    text: "No networks found."

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Repeater {
                    model: wifiDevice
                        ? wifiDevice.networks
                        : null

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        radius: 7

                        color: modelData.connected
                            ? Colors.surface1
                            : Colors.surface0

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 10
                            anchors.rightMargin: 6

                            spacing: 8

                            Text {
                                text: popup.wifiIcon(modelData)

                                color: modelData.connected
                                    ? Colors.blue
                                    : Colors.subtext0

                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                spacing: 0

                                Text {
                                    text: modelData.name

                                    color: Colors.text

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11

                                    Layout.fillWidth: true

                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.connected
                                        ? "Connected"
                                        : modelData.known
                                            ? "Saved"
                                            : "Available"

                                    color: modelData.connected
                                        ? Colors.green
                                        : Colors.subtext0

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                visible: !modelData.connected &&
                                         modelData.known

                                text: "󰌶"

                                color: Colors.subtext0

                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            Text {
                                visible: !modelData.connected &&
                                         !modelData.known

                                text: "󰌾"

                                color: Colors.subtext0

                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }

                            Rectangle {
                                visible: modelData.connected

                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.surface0

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.disconnect()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "Disconnect"

                                    color: Colors.subtext0

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                }
                            }

                            Rectangle {
                                visible: !modelData.connected

                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.lavender

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: popup.connectWifi(modelData)
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: modelData.known
                                        ? "Connect"
                                        : "Join"

                                    color: Colors.base

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                visible: modelData.known

                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.surface0

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.forget()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "×"

                                    color: Colors.red

                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Bluetooth expanded section
        // ─────────────────────────────────────────────────────────────

        Rectangle {
            visible: bluetoothExpanded

            Layout.fillWidth: true

            implicitHeight: bluetoothColumn.implicitHeight + 20

            radius: 10

            color: Colors.mantle

            border.width: 1
            border.color: Colors.surface1

            ColumnLayout {
                id: bluetoothColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top

                    margins: 10
                }

                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Bluetooth Devices"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold

                        Layout.fillWidth: true
                    }

                    MouseArea {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        onClicked: {
                            if (bluetoothAdapter)
                                bluetoothAdapter.discovering =
                                    !bluetoothAdapter.discovering
                        }

                        Text {
                            anchors.centerIn: parent

                            text: "󰑐"

                            color: bluetoothAdapter &&
                                   bluetoothAdapter.discovering
                                ? Colors.lavender
                                : Colors.subtext0

                            font.pixelSize: 17
                        }
                    }
                }

                Text {
                    visible: !bluetoothAdapter ||
                             !bluetoothAdapter.enabled

                    text: "Bluetooth is disabled."

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Repeater {
                    model: bluetoothAdapter
                        ? bluetoothAdapter.devices
                        : null

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        radius: 7

                        color: modelData.connected
                            ? Colors.surface1
                            : Colors.surface0

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 10
                            anchors.rightMargin: 6

                            spacing: 8

                            Text {
                                text: popup.bluetoothIcon(modelData)

                                color: modelData.connected
                                    ? Colors.blue
                                    : Colors.subtext0

                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 19
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                spacing: 0

                                Text {
                                    text: modelData.name ||
                                          modelData.deviceName ||
                                          "Unknown device"

                                    color: Colors.text

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11

                                    Layout.fillWidth: true

                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: {
                                        if (modelData.pairing)
                                            return "Pairing…"

                                        if (modelData.connected)
                                            return modelData.batteryAvailable
                                                ? "Connected • " +
                                                  Math.round(modelData.battery * 100) +
                                                  "%"
                                                : "Connected"

                                        if (modelData.paired)
                                            return "Paired"

                                        return "Available"
                                    }

                                    color: modelData.connected
                                        ? Colors.green
                                        : Colors.subtext0

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                visible: !modelData.paired &&
                                         !modelData.pairing

                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.lavender

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.pair()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "Pair"

                                    color: Colors.base

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                visible: modelData.paired &&
                                         !modelData.connected

                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.lavender

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.connect()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "Connect"

                                    color: Colors.base

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                visible: modelData.connected

                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.surface0

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.disconnect()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "Disconnect"

                                    color: Colors.subtext0

                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                }
                            }

                            Rectangle {
                                visible: modelData.paired

                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28

                                radius: 6

                                color: Colors.surface0

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: modelData.forget()
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "×"

                                    color: Colors.red

                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Volume
        // ─────────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            radius: 10

            color: Colors.surface0

            border.width: 1
            border.color: Colors.surface1

            RowLayout {
                anchors.fill: parent

                anchors.leftMargin: 12
                anchors.rightMargin: 12

                spacing: 10

                MouseArea {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    onClicked: {
                        if (audioSink && audioSink.audio)
                            audioSink.audio.muted =
                                !audioSink.audio.muted
                    }

                    Text {
                        anchors.centerIn: parent

                        text: audioSink &&
                              audioSink.audio &&
                              audioSink.audio.muted
                            ? "󰝟"
                            : "󰕾"

                        color: audioSink &&
                               audioSink.audio &&
                               !audioSink.audio.muted
                            ? Colors.lavender
                            : Colors.subtext0

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 3

                    Text {
                        text: audioSink && audioSink.audio
                            ? Math.round(audioSink.audio.volume * 100) + "%"
                            : "0%"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Slider {
                        Layout.fillWidth: true

                        from: 0
                        to: 1

                        value: audioSink && audioSink.audio
                            ? audioSink.audio.volume
                            : 0

                        onMoved: {
                            if (audioSink && audioSink.audio)
                                audioSink.audio.volume = value
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Brightness
        // ─────────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            radius: 10

            color: Colors.surface0

            border.width: 1
            border.color: Colors.surface1

            RowLayout {
                anchors.fill: parent

                anchors.leftMargin: 12
                anchors.rightMargin: 12

                spacing: 10

                Text {
                    text: "󰃠"

                    color: Colors.lavender

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 3

                    Text {
                        text: brightness + "%"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Slider {
                        Layout.fillWidth: true

                        from: 1
                        to: 100

                        value: popup.brightness

                        onMoved: popup.changeBrightness(value)
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Bottom actions
        // ─────────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true

            height: 1

            color: Colors.surface1
        }

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                radius: 9

                color: Colors.surface0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        popup.close()
                        popup.run([
                            "systemsettings"
                        ])
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                        text: "󰒓"

                        color: Colors.subtext0

                        font.pixelSize: 18
                    }

                    Text {
                        text: "Settings"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10

                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                radius: 9

                color: Colors.surface0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        popup.close()

                        popup.run([
                            "loginctl",
                            "lock-session"
                        ])
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                        text: "󰌾"

                        color: Colors.subtext0

                        font.pixelSize: 18
                    }

                    Text {
                        text: "Lock"

                        color: Colors.text

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10

                        Layout.fillWidth: true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                radius: 9

                color: Colors.surface0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        popup.close()

                        popup.run([
                            "systemctl",
                            "suspend"
                        ])
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "󰤄  Suspend"

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                radius: 9

                color: Colors.surface0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        popup.close()

                        popup.run([
                            "systemctl",
                            "reboot"
                        ])
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "󰜉  Reboot"

                    color: Colors.subtext0

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                radius: 9

                color: Colors.surface0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        popup.close()

                        popup.run([
                            "systemctl",
                            "poweroff"
                        ])
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "󰐥  Power"

                    color: Colors.red

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Wi-Fi password dialog
    // ─────────────────────────────────────────────────────────────────

    PopupWindow {
        id: passwordDialog

        anchor.window: popup

        anchor.rect.x: popup.width / 2 - width / 2
        anchor.rect.y: popup.height / 2 - height / 2

        width: 340
        height: 190

        visible: false
        grabFocus: true

        color: "transparent"

        Rectangle {
            anchors.fill: parent

            radius: 12

            color: Colors.base

            border.width: 1
            border.color: Colors.surface1

            ColumnLayout {
                anchors.fill: parent

                anchors.margins: 16

                spacing: 10

                Text {
                    text: "Connect to Wi-Fi"

                    color: Colors.text

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Text {
                    text: pendingWifiName

                    color: Colors.lavender

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                TextField {
                    id: passwordField

                    Layout.fillWidth: true

                    placeholderText: "Password"

                    echoMode: TextInput.Password

                    color: Colors.text

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11

                    background: Rectangle {
                        radius: 7

                        color: Colors.surface0

                        border.width: 1
                        border.color: passwordField.activeFocus
                            ? Colors.lavender
                            : Colors.surface1
                    }

                    Keys.onReturnPressed: {
                        popup.connectWifiWithPassword(text)
                        passwordDialog.visible = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 70
                        height: 32

                        radius: 7

                        color: Colors.surface0

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                passwordDialog.visible = false
                                passwordField.text = ""
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: "Cancel"

                            color: Colors.subtext0

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        width: 70
                        height: 32

                        radius: 7

                        color: Colors.lavender

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                popup.connectWifiWithPassword(
                                    passwordField.text
                                )

                                passwordDialog.visible = false
                                passwordField.text = ""
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: "Connect"

                            color: Colors.base

                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}
