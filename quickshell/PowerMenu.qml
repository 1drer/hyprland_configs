import QtQuick
import QtQuick.Layouts
import Quickshell
import "./theme"
import "./services"

PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    focusable: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ── Sizing ────────────────────────────────────────────────────

    readonly property int cellSize: 84
    readonly property int cellSpacing: 4

    readonly property int menuWidth:
        16 + root.actions.length * root.cellSize +
            (root.actions.length - 1) * root.cellSpacing

    readonly property int menuHeight:
        16 + root.cellSize

    // ── Actions (same order as the rofi power menu) ────────────────

    readonly property var actions: [
        {
            icon: "󰐥",
            label: "Shutdown",
            colorKey: "danger",
            delay: 300,
            command: [ "hyprshutdown", "-t", "Shutting down...", "--post-cmd", "shutdown -P 0" ]
        },
        {
            icon: "󰑓",
            label: "Restart",
            colorKey: "warning",
            delay: 300,
            command: [ "hyprshutdown", "-t", "Restarting...", "--post-cmd", "reboot" ]
        },
        {
            icon: "󰍃",
            label: "Log Out",
            colorKey: "accent",
            delay: 200,
            command: [ "hyprshutdown", "-t", "Logging out..." ]
        },
        {
            icon: "󰒲",
            label: "Suspend",
            colorKey: "info",
            delay: 300,
            command: [ "systemctl", "suspend" ]
        },
        {
            icon: "󰌾",
            label: "Lock",
            colorKey: "success",
            delay: 150,
            command: [ "hyprlock" ]
        }
    ]

    property int selectedIndex: 0

    // ── Dim backdrop — everything behind gets darker ──────────────

    // With ExclusionMode.Ignore the window is click-through wherever no
    // input mask is set — cover the full-screen backdrop so the buttons
    // and the dismiss-click both receive input.
    Region {
        id: windowRegion

        item: backdrop
    }

    mask: windowRegion

    Rectangle {
        id: backdrop

        anchors.fill: parent

        color: "#000000"
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        // Click anywhere on the backdrop to dismiss the menu.
        MouseArea {
            anchors.fill: parent

            onClicked: {
                PowerMenuState.close()
            }
        }
    }

    // ── Panel ─────────────────────────────────────────────────────

    Rectangle {
        id: menuSurface

        anchors.centerIn: parent

        transformOrigin: Item.Center

        opacity: 0
        scale: 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        width: root.menuWidth
        height: root.menuHeight

        radius: 0

        color:
            ThemeManager.background

        border.width: 2

        border.color:
            ThemeManager.accent

        Column {
            id: menuLayout

            anchors.centerIn: parent

            // ── Actions ───────────────────────────────────────────

            Row {
                spacing: root.cellSpacing

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: root.cellSize
                        height: root.cellSize

                        color:
                            root.selectedIndex === index
                                ? ThemeManager[modelData.colorKey]
                                : root.tinted(
                                    ThemeManager[modelData.colorKey], 0.18)

                        Text {
                            text: modelData.icon

                            anchors.centerIn: parent

                            color:
                                root.selectedIndex === index
                                    ? ThemeManager.background
                                    : ThemeManager[modelData.colorKey]

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize: 44
                        }

                        MouseArea {
                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onEntered:
                                root.selectedIndex = index

                            onPositionChanged:
                                root.selectedIndex = index

                            onClicked:
                                root.runAction(index)
                        }
                    }
                }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────

    function tinted(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function runAction(index) {
        const action = root.actions[index]

        if (!action)
            return

        PowerMenuState.close()

        // Give the menu time to actually disappear before the screen
        // locks or powers down — otherwise the panel lingers on screen
        // during the lock/suspend animation. The command runs from the
        // shell (see shell.qml's action executor); this window is
        // destroyed on close and cannot own the process.
        PowerMenuState.schedule(action.command, action.delay)
    }

    // ── Keyboard (escape / arrows / enter) ────────────────────────

    Item {
        id: keyboardFocus

        anchors.fill: parent

        focus: true

        Keys.onEscapePressed: {
            PowerMenuState.close()
            event.accepted = true
        }

        Keys.onLeftPressed: {
            root.selectedIndex =
                (root.selectedIndex - 1 +
                    root.actions.length) %
                root.actions.length
            event.accepted = true
        }

        Keys.onRightPressed: {
            root.selectedIndex =
                (root.selectedIndex + 1) %
                root.actions.length
            event.accepted = true
        }

        Keys.onReturnPressed: {
            root.runAction(root.selectedIndex)
            event.accepted = true
        }
    }

    Component.onCompleted: {
        // Manifest "from thin air": the dim fades in and the panel
        // fades + zooms up from the center. Done in QML (not Hyprland)
        // so no other layer surface (bar, quick settings, …) animates.
        backdrop.opacity = 0.45
        menuSurface.opacity = 1
        menuSurface.scale = 1
        keyboardFocus.forceActiveFocus()
    }
}
