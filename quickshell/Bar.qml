
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

import "./colors/Colors.js" as Colors

PanelWindow {
    id: bar

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13
    property int fontWeight: 800

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
    color: Colors.crust

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 16

        RowLayout {
          id: right
            spacing: 8

            // ---- Workspaces ----
Row {
    id: workspaceRow
    spacing: 4

    property var wsIds: {
        const ids = new Set([1, 2, 3, 4, 5])

        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0)
                ids.add(ws.id)
        }

        return Array.from(ids).sort((a, b) => a - b)
    }

    Repeater {
        model: workspaceRow.wsIds

        delegate: Rectangle {
            id: workspaceButton

            required property int modelData

            readonly property int wsId: modelData
            readonly property var workspace:
                Hyprland.workspaces.values.find(w => w.id === wsId)

            readonly property bool active:
                Hyprland.focusedWorkspace?.id === wsId

            readonly property bool occupied:
                workspace !== undefined

            readonly property bool urgent:
                workspace?.urgent ?? false

            width: bar.height - 8   
            height: bar.height - 8

            color: urgent
                ? Colors.red
                : active
                    ? Colors.lavender
                    : "transparent"

            Text {
                anchors.fill: parent
                anchors.margins: 0

                text: workspaceButton.wsId
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize
                font.weight: !workspaceButton.occupied ? bar.fontWeight - 200 : bar.fontWeight

                color: workspaceButton.active || workspaceButton.urgent
                    ? Colors.crust
                    : workspaceButton.occupied
                        ? Colors.lavender
                        : Colors.subtext0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: workspaceButton.workspace?Qt.PointingHandCursor:Qt.CursorArrow

                onClicked: {
                   
                        workspaceButton.workspace.activate()                }
            }
        }
    }
  }

            // ---- Active window title ----
Rectangle {
    id: activeWindowContainer

    readonly property var activeWindow:
        Hyprland.activeToplevel

    readonly property bool hasActiveWindow:
        activeWindow !== null &&
        activeWindow.workspace === Hyprland.focusedWorkspace

    visible: hasActiveWindow

    color: Colors.surface0

    implicitHeight: bar.implicitHeight - 8
    implicitWidth: Math.min(activeWindowText.implicitWidth + 16, 250)

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        width: 2
        color: Colors.lavender
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

        text: activeWindowContainer.activeWindow?.title ?? ""

        font.family: bar.fontFamily
        font.pixelSize: bar.fontSize
        font.weight: bar.fontWeight

        color: Colors.text

        elide: Text.ElideRight
        maximumLineCount: 1
    }
} 
}}
            // ---- Clock ----
            Text {
              id: clock
              anchors.centerIn: parent
                font.family: bar.fontFamily
                font.pixelSize: bar.fontSize
                font.weight: bar.fontWeight
                color: Colors.text

                function refresh() {
                    text = Qt.formatDateTime(new Date(), "MMM dd  hh:mm")
                }

                Component.onCompleted: refresh()

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock.refresh()
                }
            }

            // ---- System tray ----
                RowLayout {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 4
        anchors.rightMargin: 8
        spacing: 16


            RowLayout {
                id: trayRow
                spacing: 10

                Repeater {
                    model: SystemTray.items
                    delegate: Image {
                        required property var modelData
                        source: modelData.icon
                        width: 16
                        height: 16
                        sourceSize: Qt.size(16, 16)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton)
                                    modelData.display(bar, mouse.x, mouse.y)
                                else
                                    modelData.activate()
                            }
                        }
                    }
                }
              }

Text {
    id: volumeText

    readonly property var sink:
        Pipewire.defaultAudioSink

    readonly property int volume:
        sink?.audio
            ? Math.round(sink.audio.volume * 100)
            : 0

    readonly property bool muted:
        sink?.audio?.muted ?? false

    PwObjectTracker {
        objects: [volumeText.sink]
    }

    text: muted
        ? "Muted"
        : volume + "%"

    color: muted
        ? Colors.subtext0
        : Colors.lavender

    font.family: bar.fontFamily
    font.weight: bar.fontWeight
    font.pixelSize: bar.fontSize
}

Text {
    id: wifiText

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
            ? Math.round(connectedNetwork.signalStrength * 100)
            : 0

            text: !wifiEnabled
        ? "Off"
        : connected
            ? "  " + signalStrength + "%"
            : ""

    color: connected
        ? Colors.blue
        : Colors.subtext0

    font.family: bar.fontFamily
    font.weight: bar.fontWeight
    font.pixelSize: bar.fontSize
  }

Text {
    id: bluetoothText

    readonly property var bluetoothAdapter:
        Bluetooth.defaultAdapter

    readonly property bool bluetoothEnabled:
        bluetoothAdapter?.enabled ?? false

    readonly property int connectedDevices:
        Bluetooth.devices.values.filter(
            device => device.connected
        ).length

    text: !bluetoothEnabled
        ? "Off"
        : connectedDevices > 0
            ? "BT: " + connectedDevices
            : "BT"

    color: connectedDevices
        ? Colors.blue
        : bluetoothEnabled
            ? Colors.lavender
            : Colors.subtext0

    font.family: bar.fontFamily
    font.weight: bar.fontWeight
    font.pixelSize: bar.fontSize
}

Text {
    id: powerProfileText

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
            return Colors.green

        case PowerProfile.Balanced:
            return Colors.lavender

        case PowerProfile.Performance:
            return Colors.red

        default:
            return Colors.lavender
        }
    }

    font.family: bar.fontFamily
    font.weight: bar.fontWeight
    font.pixelSize: bar.fontSize
}

  Text {
    id: batteryText

    property var battery: UPower.displayDevice
    property bool pluggedIn: !UPower.onBattery
    property bool shouldBlink:
        battery.ready && !pluggedIn && battery.percentage <= 0.05

    function batteryColor(pct, plugged) {
        if (plugged)
            return Colors.green

        if (pct <= 0.10)
            return Colors.red

        if (pct <= 0.20)
            return Colors.yellow

        if (pct <= 0.30)
            return Colors.peach

        return Colors.lavender
    }

    text: battery.ready
        ? Math.round(battery.percentage * 100) + "%"
        : ""

    color: battery.ready
        ? batteryColor(battery.percentage, pluggedIn)
        : Colors.lavender

    font.family: bar.fontFamily
    font.weight: bar.fontWeight
    font.pixelSize: bar.fontSize

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
        loops: Animation.Infinite

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
    




