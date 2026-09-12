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
        top: 0
        left: 0
        right: 0
    }

    implicitHeight: 28

    color:
        ThemeManager.backgroundDeep

    // ═══════════════════════════════════════════════════════════════════
    // Tray Menu State
    // ═══════════════════════════════════════════════════════════════════

    property Item activeTrayIcon: null

    function openTrayMenu(icon) {
        trayMenuPopup.openFor(icon)
    }

    function closeTrayMenu() {
        trayMenuPopup.closeMenu()
    }

    function toggleTrayMenu(icon) {
        trayMenuPopup.toggleFor(icon)
    }

    // ═══════════════════════════════════════════════════════════════════
    // Main Layout
    // ═══════════════════════════════════════════════════════════════════

    Item {
        anchors.fill: parent

        // ═══════════════════════════════════════════════════════════════
        // LEFT
        // ═══════════════════════════════════════════════════════════════

        RowLayout {
            id: left

            anchors {
                left: parent.left
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }

            spacing: 8

            // ═══════════════════════════════════════════════════════════
            // Workspaces
            // ═══════════════════════════════════════════════════════════

            Item {
                id: workspaceContainer

                implicitWidth:
                    workspaceRow.implicitWidth

                implicitHeight:
                    bar.implicitHeight - 8

                Rectangle {
                    id: activeWorkspaceIndicator

                    width:
                        bar.implicitHeight - 8

                    height:
                        bar.implicitHeight - 8

                    radius: 0

                    color:
                        ThemeManager.accent

                    z: 0

                    x: {
                        var focusedId =
                            Hyprland.focusedWorkspace?.id

                        for (
                            var i = 0;
                            i < workspaceRepeater.count;
                            i++
                        ) {
                            var item =
                                workspaceRepeater.itemAt(i)

                            if (
                                item &&
                                item.wsId === focusedId
                            ) {
                                return item.x
                            }
                        }

                        return 0
                    }

                    Behavior on x {
                        SpringAnimation {
                            spring: 7
                            damping: 0.4
                            velocity: 0
                        }
                    }
                }

                Row {
                    id: workspaceRow

                    spacing: 4

                    z: 1

                    property var wsIds: {
                        const ids = new Set([
                            1,
                            2,
                            3,
                            4,
                            5
                        ])

                        for (
                            const ws
                            of Hyprland.workspaces.values
                        ) {
                            if (ws.id > 0)
                                ids.add(ws.id)
                        }

                        return Array.from(ids).sort(
                            (a, b) => a - b
                        )
                    }

                    Repeater {
                        id: workspaceRepeater

                        model:
                            workspaceRow.wsIds

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
                                Hyprland.focusedWorkspace?.id ===
                                wsId

                            readonly property bool occupied:
                                workspace !== undefined

                            readonly property bool urgent:
                                workspace?.urgent ?? false

                            width:
                                bar.implicitHeight - 8

                            height:
                                bar.implicitHeight - 8

                            color:
                                urgent
                                    ? ThemeManager.danger
                                    : "transparent"

                            Text {
                                anchors.fill: parent

                                text:
                                    workspaceButton.wsId

                                horizontalAlignment:
                                    Text.AlignHCenter

                                verticalAlignment:
                                    Text.AlignVCenter

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontNormal

                                font.weight:
                                    ThemeManager.fontHeavy

                                color:
                                    workspaceButton.urgent
                                        ? ThemeManager.backgroundDeep
                                        : workspaceButton.active
                                            ? ThemeManager.backgroundDeep
                                            : workspaceButton.occupied
                                                ? ThemeManager.accent
                                                : ThemeManager.overlaySecondary
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    workspaceButton.workspace
                                        ? Qt.PointingHandCursor
                                        : Qt.ArrowCursor

                                onClicked: {
                                    if (
                                        workspaceButton.workspace
                                    ) {
                                        workspaceButton.workspace.activate()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════
            // Active Window
            // ═══════════════════════════════════════════════════════════

            Rectangle {
                id: activeWindowContainer

                readonly property var activeWindow:
                    Hyprland.activeToplevel

                readonly property bool hasActiveWindow:
                    activeWindow !== null &&
                    activeWindow.workspace ===
                        Hyprland.focusedWorkspace

                visible:
                    hasActiveWindow

                color:
                    ThemeManager.surface

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

                    color:
                        ThemeManager.accent
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

                    maximumLineCount: 1
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT
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

            MouseArea {
                id: controlCenterMouseArea

                anchors.fill: parent

                z: 0

                cursorShape:
                    Qt.PointingHandCursor

                onClicked:
                    ControlCenterState.toggle()
            }

            RowLayout {
                id: rightRow

                anchors.fill: parent

                spacing: 12

                // ═══════════════════════════════════════════════════════
                // COLLAPSIBLE SYSTEM TRAY
                // ═══════════════════════════════════════════════════════

                Item {
                    id: trayContainer

                    Layout.alignment:
                        Qt.AlignVCenter

                    // Start collapsed
                    property bool expanded: false

                    // Reactive list of tray items.
                    // ObjectModel.values updates when tray items
                    // are registered/unregistered.
                    readonly property var trayItems:
                        SystemTray.items.values

                    readonly property bool hasTrayItems:
                        trayItems.length > 0

                    readonly property int iconSize: 16

                    readonly property int toggleWidth: 12

                    readonly property int traySpacing: 10

                    // Completely remove the tray from the
                    // layout when there are no tray applications.
                    visible:
                        hasTrayItems

                    implicitWidth:
                        hasTrayItems
                            ? toggleWidth +
                              (
                                  expanded
                                      ? traySpacing +
                                        trayIconsRow.implicitWidth
                                      : 0
                              )
                            : 0

                    implicitHeight:
                        bar.implicitHeight - 8

                    clip: true

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: 180

                            easing.type:
                                Easing.OutCubic
                        }
                    }

                    // ═══════════════════════════════════════════════
                    // Collapse / Expand Pointer
                    // ═══════════════════════════════════════════════

                    Item {
                        id: trayToggle

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width:
                            trayContainer.toggleWidth

                        height:
                            trayContainer.iconSize

                        Text {
                            anchors.centerIn: parent

                            text:
                                trayContainer.expanded
                                    ? ""
                                    : ""

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontIcon - 1

                            font.weight:
                                ThemeManager.fontHeavy

                            color:
                                trayToggleMouse.containsMouse
                                    ? ThemeManager.text
                                    : ThemeManager.textMuted

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                        }

                        MouseArea {
                            id: trayToggleMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            z: 20

                            cursorShape:
                            Qt.PointingHandCursor

                          


                            onClicked: {
                                trayContainer.expanded =
                                    !trayContainer.expanded
                            }
                        }
                    }

                    // ═══════════════════════════════════════════════
                    // Tray Icons
                    // ═══════════════════════════════════════════════

                    Item {
                        id: trayIconsContainer

                        anchors {
                            left:
                                trayToggle.right

                            leftMargin:
                                trayContainer.traySpacing

                            verticalCenter:
                                parent.verticalCenter
                        }

                        implicitWidth:
                            trayIconsRow.implicitWidth

                        implicitHeight:
                            trayIconsRow.implicitHeight

                        clip: true

                        opacity:
                            trayContainer.expanded
                                ? 1
                                : 0

                        x:
                            trayContainer.expanded
                                ? 0
                                : -20

                        Behavior on x {
                            NumberAnimation {
                                duration: 180

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120

                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        Row {
                            id: trayIconsRow

                            anchors.fill: parent

                            spacing:
                                trayContainer.traySpacing

                            Repeater {
                                model:
                                    SystemTray.items

                                delegate: Item {
                                    id: trayIcon

                                    required property var modelData

                                    width:
                                        trayContainer.iconSize

                                    height:
                                        trayContainer.iconSize

                                    Image {
                                        anchors.fill: parent

                                        source:
                                            modelData.icon

                                        sourceSize:
                                            Qt.size(
                                                trayContainer.iconSize,
                                                trayContainer.iconSize
                                            )

                                        asynchronous: true

                                        smooth: true
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
                                                    Qt.LeftButton &&
                                                !modelData.onlyMenu
                                            ) {
                                                modelData.activate()
                                            } else if (
                                                modelData.hasMenu
                                            ) {
                                                bar.toggleTrayMenu(
                                                    trayIcon
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════════════════════
                // Volume
                // ═══════════════════════════════════════════════════════
//                 Text {
//     id: volumeText

//     z: 1

//     readonly property var sink:
//         Pipewire.defaultAudioSink

//     readonly property int volume:
//         sink?.audio
//             ? Math.round(
//                 sink.audio.volume * 100
//             )
//             : 0

//     readonly property bool muted:
//         sink?.audio?.muted ?? false

//     PwObjectTracker {
//         objects: [
//             volumeText.sink
//         ]
//     }

//     text:
//         muted
//             ? ""
//             : volume <= 20
//                 ? ""
//                 : volume <= 40
//                     ? ""
//                     : volume <= 70
//                       ?""
//                       :""

//     color:
//         muted
//             ? ThemeManager.textMuted
//             : ThemeManager.accent

//     font.family:
//         ThemeManager.fontFamily

//     font.pixelSize:
//         ThemeManager.fontIcon

//     font.weight:
//         ThemeManager.fontHeavy
// }
               
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
                        objects: [
                            volumeText.sink
                        ]
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
 
                // ═══════════════════════════════════════════════════════
                // Wi-Fi
                // ═══════════════════════════════════════════════════════

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

                    visible:
                        wifiEnabled

                    text:
                        connected
                            ? "  " +
                              signalStrength +
                              "%"
                            : ""
                    
          //              text: {
        //if (!connected)
          //  return "󰤯"

        //if (signalStrength >= 75)
       // return "󰤥"
       // else if (signalStrength >= 50)
       //     return "󰤢"
      //  else if (signalStrength >= 25)
      //      return "󰤟"
    //    else
  //          return "󰤯"
//    }
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

                // ═══════════════════════════════════════════════════════
                // Bluetooth
                // ═══════════════════════════════════════════════════════

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

                    visible:
                        bluetoothEnabled

                    text:
                        connectedDevices > 0
                            ? "BT " +
                              connectedDevices
                            : "BT"

                    color:
                        connectedDevices > 0
                            ? ThemeManager.info
                            : ThemeManager.accent

                    font.family:
                        ThemeManager.fontFamily

                    font.pixelSize:
                        ThemeManager.fontNormal

                    font.weight:
                        ThemeManager.fontHeavy
                }

                // ═══════════════════════════════════════════════════════
                // Power Profile
                // ═══════════════════════════════════════════════════════

                Text {
                    id: powerProfileText

                    z: 1

                    readonly property var profile:
                        PowerProfiles.profile

                    visible:
                        profile ===
                            PowerProfile.PowerSaver ||
                        profile ===
                            PowerProfile.Performance

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

                // ═══════════════════════════════════════════════════════
                // Battery
                // ═══════════════════════════════════════════════════════

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

                    function batteryColor(
                        pct,
                        plugged
                    ) {
                        if (plugged)
                            return ThemeManager.success

                        if (pct <= 0.10)
                            return ThemeManager.danger

                        if (pct <= 0.30)
                            return ThemeManager.warning

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
                            target:
                                batteryText

                            property:
                                "opacity"

                            from: 1.0

                            to: 0.2

                            duration: 500
                        }

                        NumberAnimation {
                            target:
                                batteryText

                            property:
                                "opacity"

                            from: 0.2

                            to: 1.0

                            duration: 500
                        }
                    }
                  }
                  Text {
    id: clock2
   visible: false
    font.family: ThemeManager.fontFamily
    font.pixelSize: ThemeManager.fontNormal+1
    font.weight: ThemeManager.fontHeavy

    color: ThemeManager.text

    text: Qt.formatDateTime(
        new Date(),
        "hh:mm AP"
    )
}
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // CENTER CLOCK
        // ═══════════════════════════════════════════════════════════════

        Text {
            id: clock
            visible: true
            anchors.centerIn: parent

            font.family:
                ThemeManager.fontFamily

            font.pixelSize:
                ThemeManager.fontNormal

            font.weight:
                ThemeManager.fontHeavy

            color:
                ThemeManager.text

            property bool showDate: false

            function refresh() {
                if (showDate) {
                    text =
                        Qt.formatDateTime(
                            new Date(),
                            "dd MMM yyyy"
                        )
                } else {
                    text =
                        Qt.formatDateTime(
                            new Date(),
                            "dddd, hh:mm"
                        )
                }
            }

            MouseArea {
                anchors.fill: parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {
                    clock.showDate =
                        !clock.showDate

                    clock.refresh()
                }
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

    // ═══════════════════════════════════════════════════════════════════
    // Themed System Tray Menu
    // ═══════════════════════════════════════════════════════════════════

    TrayMenu {
        id: trayMenuPopup

        barWindow:
            bar
    }
}
