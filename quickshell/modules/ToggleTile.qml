import QtQuick
import QtQuick.Layouts
import "../theme"

// ─────────────────────────────────────────────────────────────────────
// ToggleTile — reusable quick-toggle tile for the control center.
//
//   * plain tile   — icon + label; fills with `activeColor` when
//                    `checked`, neutral surface + hover otherwise.
//   * expand tile  — `expandable: true` reserves the right-hand 20%
//                    as a separate click target that toggles `expanded`
//                    and fires `expand()` (used by wifi/bluetooth).
//
// Adding a new quick toggle is one instance in the panel:
//
//     ToggleTile {
//         icon: "󰗑"
//         label: "Balanced"
//         checked: root.xxxRunning
//         activate: () => root.toggleXxx()
//     }
// ─────────────────────────────────────────────────────────────────────

Rectangle {
    id: root

    // ── Public API ───────────────────────────────────────────────

    required property string label
    required property string icon

    property bool checked: false

    // Fill color when `checked` (and the tile border highlight).
    property color activeColor: ThemeManager.accent

    // Icon colors. Defaults invert to the accent/background scheme;
    // override e.g. for the power-profile tile (profile-colored icon).
    property color iconColorChecked: ThemeManager.background
    property color iconColorUnchecked: ThemeManager.textMuted

    // Expand slot (optional).
    property bool expandable: false
    property bool expanded: false

    property var activate: null   // () => void   — main area click
    property var expand: null     // () => void   — expand slot click

    property int tileHeight: 44

    // ── Tile shell ───────────────────────────────────────────────

    Layout.fillWidth: true
    Layout.preferredHeight: root.tileHeight

    radius: 0

    color:
        root.expandable
            ? ThemeManager.surface
            : root.checked
                ? root.activeColor
                : mainHover.containsMouse
                    ? ThemeManager.surfaceSecondary
                    : ThemeManager.surface

    border.width: 1

    border.color:
        root.checked || root.expanded
            ? root.activeColor
            : ThemeManager.surfaceSecondary

    // ── Main area ────────────────────────────────────────────────

    Rectangle {
        id: mainArea

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        width:
            root.expandable
                ? parent.width * 0.80
                : parent.width

        color:
            root.checked
                ? root.activeColor
                : mainHover.containsMouse
                    ? ThemeManager.surfaceSecondary
                    : ThemeManager.surface

        MouseArea {
            id: mainHover

            anchors.fill: parent

            hoverEnabled: true

            cursorShape:
                Qt.PointingHandCursor

            onClicked: {
                if (root.activate)
                    root.activate()
            }
        }

        Row {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            anchors.leftMargin: 11
            anchors.rightMargin: 11

            spacing: 12

            Text {
                text: root.icon

                width: 20

                color:
                    root.checked
                        ? root.iconColorChecked
                        : root.iconColorUnchecked

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize: 20

                anchors.verticalCenter:
                    parent.verticalCenter

                horizontalAlignment:
                    Text.AlignHCenter
            }

            Text {
                text: root.label

                color:
                    root.checked
                        ? ThemeManager.background
                        : ThemeManager.text

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontNormal

                font.weight:
                    ThemeManager.fontBold

                width:
                    parent.width - 22 - 20 - 12

                anchors.verticalCenter:
                    parent.verticalCenter

                elide:
                    Text.ElideRight
            }
        }
    }

    // ── Expand slot ──────────────────────────────────────────────

    Rectangle {
        visible: root.expandable

        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }

        width:
            parent.width * 0.20

        // The expand slot NEVER turns accent when checked — it only
        // gains the normal hover highlight plus an accent border.
        color:
            expandHover.containsMouse
                ? ThemeManager.surfaceSecondary
                : ThemeManager.surface

        border.width:
            root.checked ? 2 : 0

        border.color:
            ThemeManager.accent

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width:
                root.checked ? 0 : 1

            color:
                ThemeManager.surfaceSecondary
        }

        MouseArea {
            id: expandHover

            anchors.fill: parent

            hoverEnabled: true

            cursorShape:
                Qt.PointingHandCursor

            onClicked: {
                if (root.expand)
                    root.expand()
            }
        }

        Text {
            anchors.centerIn: parent

            text:
                root.expanded
                    ? "󰅃"
                    : "󰅀"

            // ONLY the pointer becomes accent when expanded.
            color:
                root.expanded
                    ? ThemeManager.accent
                    : ThemeManager.textMuted

            font.family:
                ThemeManager.fontFamily

            font.pixelSize: 18
        }
    }
}