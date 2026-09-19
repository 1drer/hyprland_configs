import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ─────────────────────────────────────────────────────────────────────
// SliderRow — reusable icon + slider row (volume / brightness /
// warmth). The icon and the slider bar/handle share `fillColor`; the
// icon can be turned into a clickable button (the volume mute toggle)
// via `iconClickable` + `onIconClicked`.
// ─────────────────────────────────────────────────────────────────────

RowLayout {
    id: root

    // ── Public API ───────────────────────────────────────────────

    required property string icon

    property color iconColor: ThemeManager.accent
    property color fillColor: ThemeManager.accent

    property bool iconClickable: false
    property var onIconClicked: null

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0

    // Warmth slider: while pressed, follow the live drag position
    // instead of the bound value so the debounced write-back doesn't
    // fight the handle every frame.
    property bool liveWhilePressed: false

    property var onMoved: null  // (value) => void

    // ── Layout ───────────────────────────────────────────────────

    Layout.fillWidth: true

    spacing: 10

    // ── Icon button (only when iconClickable) ────────────────────

    MouseArea {
        visible: root.iconClickable

        Layout.preferredWidth: 26
        Layout.preferredHeight: 26

        hoverEnabled: true

        cursorShape:
            Qt.PointingHandCursor

        onClicked: {
            if (root.onIconClicked)
                root.onIconClicked()
        }

        Text {
            anchors.centerIn: parent

            text: root.icon

            color: root.iconColor

            font.family:
                ThemeManager.fontFamily

            font.pixelSize: 21
        }
    }

    // ── Icon (static) ────────────────────────────────────────────

    Text {
        visible: !root.iconClickable

        text: root.icon

        color: root.iconColor

        font.family:
            ThemeManager.fontFamily

        font.pixelSize: 21

        Layout.preferredWidth: 26

        horizontalAlignment:
            Text.AlignHCenter

        Layout.alignment:
            Qt.AlignVCenter
    }

    // ── Slider ───────────────────────────────────────────────────

    Slider {
        id: slider

        Layout.fillWidth: true

        Layout.preferredHeight: 26

        from: root.from
        to: root.to
        stepSize: root.stepSize

        value:
            root.liveWhilePressed
                ? slider.pressed ? slider.value : root.value
                : root.value

        onMoved: {
            if (root.onMoved)
                root.onMoved(value)
        }

        background: Rectangle {
            x:
                slider.leftPadding

            y:
                slider.topPadding +
                slider.availableHeight / 2 -
                height / 2

            implicitWidth: 200
            implicitHeight: 4

            width:
                slider.availableWidth

            height:
                implicitHeight

            radius: 0

            color:
                ThemeManager.surfaceSecondary

            Rectangle {
                width:
                    slider.visualPosition *
                    parent.width

                height:
                    parent.height

                color: root.fillColor
            }
        }

        handle: Rectangle {
            x:
                slider.leftPadding +
                slider.visualPosition *
                (
                    slider.availableWidth -
                    width
                )

            y:
                slider.topPadding +
                slider.availableHeight / 2 -
                height / 2

            implicitWidth: 14
            implicitHeight: 14

            width:
                implicitWidth

            height:
                implicitHeight

            radius: 0

            color: root.fillColor
        }
    }
}