import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

import "../theme"

// A themed, cascading system tray menu.
//
// Renders a tray item's DBus menu (and any nested submenus) as a flat,
// ThemeManager-styled QML popup instead of the native platform menu. The
// window covers the whole output so clicking anywhere outside a menu box
// dismisses the menu.
//
// Note on coordinates: the target items live in the bar window while this
// overlay is its own window. All geometry comparisons therefore go through
// mapToGlobal() (which yields output coordinates and matches this window's
// origin); mapToItem() is never used here because its target must be an
// Item, not a window.

PanelWindow {
    id: menuRoot

    // The bar window this menu is anchored to.
    property var barWindow: null

    // The tray icon delegate whose menu is currently shown.
    property Item activeIcon: null

    // The QsMenuHandle (SystemTrayItem.menu) being displayed.
    property var openedHandle: null

    // Last known pointer position, in output coordinates. Kept fresh by every
    // hover-capable MouseArea so submenus can stay open while the cursor is
    // moving between a parent row and its child menu.
    property point pointerPos: Qt.point(-1, -1)

    function setPointer(area, mouse) {
        menuRoot.pointerPos = area.mapToGlobal(mouse.x, mouse.y)
    }

    // Point-in-rect test against an item's global box, with an optional pad
    // so small gaps between a row and its submenu don't close anything.
    function containsPoint(item, p, pad) {
        if (!item || !p)
            return false

        pad = pad || 0

        let g
        try {
            g = item.mapToGlobal(0, 0)
        } catch (e) {
            return false
        }

        return p.x >= g.x - pad &&
            p.x <= g.x + item.width + pad &&
            p.y >= g.y - pad &&
            p.y <= g.y + item.height + pad
    }

    function placeRoot() {
        const item = rootLevelLoader.item
        if (!item)
            return

        if (!menuRoot.activeIcon) {
            rootLevelLoader.x = 40
            rootLevelLoader.y = 40
            return
        }

        let px = 40
        let py = 40

        try {
            const g = menuRoot.activeIcon.mapToGlobal(0, 0)
            px = g.x + menuRoot.activeIcon.width - item.width + 4
            py = g.y + menuRoot.activeIcon.height + 6
        } catch (e) {
            // fall through with the defaults
        }

        const maxX = Math.max(4, menuRoot.width - item.width - 4)
        const maxY = Math.max(4, menuRoot.height - item.height - 4)

        rootLevelLoader.x = Math.round(Math.max(4, Math.min(px, maxX)))
        rootLevelLoader.y = Math.round(Math.max(4, Math.min(py, maxY)))
    }

    function openFor(icon) {
        activeIcon = icon
        openedHandle = icon ? icon.modelData.menu : null
        visible = true
        Qt.callLater(function() {
            menuRoot.placeRoot()
        })
    }

    function closeMenu() {
        visible = false
        openedHandle = null
        activeIcon = null
    }

    function toggleFor(icon) {
        if (visible && activeIcon === icon)
            closeMenu()
        else
            openFor(icon)
    }

    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── Backdrop ────────────────────────────────────────────────────────
    // Covers the whole output under the menu boxes. Any click that doesn't
    // land on a menu item falls through to here and dismisses the menu.

    MouseArea {
        anchors.fill: parent

        z: -1

        hoverEnabled: true

        onPositionChanged: (mouse) =>
            menuRoot.setPointer(this, mouse)

        onClicked:
            menuRoot.closeMenu()
    }

    // ── A single menu row (item or separator) ───────────────────────────

    Component {
        id: trayMenuRow

        Item {
            id: row

            required property var modelData

            property var levelItem: null

            readonly property bool separator:
                modelData.isSeparator

            readonly property bool hasIndicator:
                modelData.buttonType ===
                    QsMenuButtonType.CheckBox ||
                modelData.buttonType ===
                    QsMenuButtonType.RadioButton

            readonly property bool hasIcon:
                modelData.icon !== ""

            readonly property bool hasArrow:
                modelData.hasChildren

            readonly property real rowPad: 8
            readonly property real rowSpacing: 8
            readonly property real rowIndicatorW: 12
            readonly property real rowIconW: 14
            readonly property real rowArrowW: 14

            // Fixed-width chrome that surrounds the label (margins +
            // indicator + icon + arrow + the small gap before the arrow),
            // so the widest row's menu still hugs its content.
            readonly property real headerFixedW:
                rowPad * 2 +
                (hasIndicator ? rowIndicatorW + rowSpacing : 0) +
                (hasIcon ? rowIconW + rowSpacing : 0) +
                (hasArrow ? rowSpacing + rowArrowW : 0) +
                12

            // What this row needs to show its full label comfortably.
            // Drives the Column (and therefore the menu) width.
            implicitWidth:
                Math.max(
                    140,
                    headerFixedW + rowLabel.implicitWidth
                )

            implicitHeight:
                separator ? 9 : 30

            // Visually stretch to the menu width so every option shares
            // the same right edge (and the "›" lines up at the box edge).
            width:
                parent ? parent.width : implicitWidth

            height:
                implicitHeight

            // The label width can change once DBus menu data arrives, so
            // re-measure the level whenever this row's need changes.
            onImplicitWidthChanged: {
                if (row.levelItem && row.levelItem.refreshWidth)
                    row.levelItem.refreshWidth()
            }

            Rectangle {
                visible:
                    row.separator

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter:
                        parent.verticalCenter
                }

                anchors.margins: 4

                height: 1

                color:
                    ThemeManager.surfaceSecondary

                opacity: 0.6
            }

            Rectangle {
                visible:
                    !row.separator

                anchors.fill: parent

                color:
                    rowMouse.containsMouse &&
                    modelData.enabled
                        ? Qt.alpha(
                            ThemeManager.accent,
                            0.15
                        )
                        : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter:
                            parent.verticalCenter
                    }

                    anchors.margins: 8

                    spacing: 8

                    Rectangle {
                        visible:
                            modelData.buttonType ===
                            QsMenuButtonType.CheckBox

                        implicitWidth: 12
                        implicitHeight: 12

                        border.width: 1
                        border.color:
                            modelData.checkState ===
                                Qt.Checked
                                ? ThemeManager.accent
                                : ThemeManager.overlaySecondary

                        color:
                            modelData.checkState ===
                                Qt.Checked
                                ? ThemeManager.accent
                                : "transparent"

                        Text {
                            visible:
                                modelData.checkState ===
                                Qt.Checked

                            anchors.centerIn: parent

                            text: "✓"

                            color:
                                ThemeManager.backgroundDeep

                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    Rectangle {
                        visible:
                            modelData.buttonType ===
                            QsMenuButtonType.RadioButton

                        implicitWidth: 12
                        implicitHeight: 12

                        radius: 6

                        border.width: 1
                        border.color:
                            modelData.checkState ===
                                Qt.Checked
                                ? ThemeManager.accent
                                : ThemeManager.overlaySecondary

                        color: "transparent"

                        Rectangle {
                            visible:
                                modelData.checkState ===
                                Qt.Checked

                            anchors.centerIn: parent

                            width: 6
                            height: 6

                            radius: 3

                            color:
                                ThemeManager.accent
                        }
                    }

                    Image {
                        visible:
                            modelData.icon !== ""

                        source:
                            modelData.icon

                        sourceSize:
                            Qt.size(14, 14)

                        width: 14
                        height: 14
                    }

                    Text {
                        id: rowLabel

                        Layout.fillWidth: true

                        text:
                            modelData.text

                        elide:
                            Text.ElideRight

                        color:
                            modelData.enabled
                                ? ThemeManager.text
                                : ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontSmall
                    }

                    Text {
                        visible:
                            modelData.hasChildren

                        text: "›"

                        color:
                            ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontSmall
                    }
                }

                MouseArea {
                    id: rowMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    acceptedButtons:
                        Qt.LeftButton |
                        Qt.RightButton

                    cursorShape:
                        modelData.enabled
                            ? Qt.PointingHandCursor
                            : Qt.ArrowCursor

                    onPositionChanged: (mouse) =>
                        menuRoot.setPointer(this, mouse)

                    onEntered:
                        row.levelItem.setHovered(row)

                    onClicked: {
                        if (!modelData.enabled)
                            return

                        if (modelData.hasChildren) {
                            row.levelItem.setHovered(row)
                            return
                        }

                        modelData.triggered()
                        menuRoot.closeMenu()
                    }
                }
            }
        }
    }

    // ── A menu level (one box + one open submenu) ───────────────────────

    Component {
        id: trayMenuLevel

        Item {
            id: levelRoot

            property var handle: null
            property int depth: 0

            property var hoveredEntry: null
            property var hoveredRow: null

            // Widest row's needed width, tracked from the row delegates so
            // the box width stays data-driven without depending on the
            // column's implicitWidth (which would otherwise form a binding
            // loop with the stretched rows).
            property real contentNeed: 0

            function refreshWidth() {
                let maxW = 0
                for (let i = 0; i < levelCol.children.length; ++i) {
                    const child = levelCol.children[i]
                    if (child.implicitWidth > maxW)
                        maxW = child.implicitWidth
                }
                levelRoot.contentNeed = maxW
            }

            implicitWidth:
                levelBox.width

            implicitHeight:
                levelBox.height

            width:
                implicitWidth

            height:
                implicitHeight

            QsMenuOpener {
                id: levelOpener

                menu:
                    levelRoot.handle
            }

            readonly property int levelBoxPad: 6

            Rectangle {
                id: levelBox

                width:
                    levelRoot.contentNeed + 2 * levelRoot.levelBoxPad

                height:
                    levelCol.implicitHeight + 2 * levelRoot.levelBoxPad

                color:
                    ThemeManager.surface

                border.width: 1
                border.color:
                    ThemeManager.surfaceSecondary

                clip: true

                Column {
                    id: levelCol

                    width:
                        levelBox.width - 2 * levelRoot.levelBoxPad

                    x: levelRoot.levelBoxPad
                    y: levelRoot.levelBoxPad

                    spacing: 2

                    Repeater {
                        id: levelRows

                        model:
                            levelOpener.children.values

                        delegate: trayMenuRow

                        onItemAdded: (index, obj) => {
                            obj.levelItem = levelRoot
                            levelRoot.refreshWidth()
                        }

                        onItemRemoved: () => {
                            levelRoot.refreshWidth()
                        }
                    }
                }
            }

            Loader {
                id: levelSub

                active:
                    levelRoot.hoveredEntry !== null &&
                    levelRoot.hoveredEntry.hasChildren

                sourceComponent: trayMenuLevel

                onLoaded: {
                    const sub = levelSub.item
                    if (!sub)
                        return

                    sub.handle = levelRoot.hoveredEntry
                    sub.depth = levelRoot.depth + 1

                    sub.widthChanged.connect(levelRoot.placeSub)
                    sub.heightChanged.connect(levelRoot.placeSub)

                    levelRoot.placeSub()
                }
            }

            // Keeps the submenu open while the pointer is anywhere near the
            // parent row or the submenu box (with a little padding so the
            // cursor can cross the gap); closes it as soon as the pointer
            // leaves both.
            Timer {
                id: closeGuard

                interval: 100
                repeat: true

                running:
                    levelRoot.hoveredEntry !== null &&
                    levelRoot.hoveredRow !== null &&
                    levelRoot.hoveredEntry.hasChildren

                onTriggered: {
                    if (!levelRoot.hoveredEntry || !levelRoot.hoveredEntry.hasChildren)
                        return

                    const p = menuRoot.pointerPos
                    if (menuRoot.containsPoint(levelRoot.hoveredRow, p, 12))
                        return
                    if (
                        levelSub.item &&
                        menuRoot.containsPoint(levelSub.item, p, 12)
                    ) {
                        return
                    }

                    levelRoot.hoveredEntry = null
                    levelRoot.hoveredRow = null
                    levelRoot.updateSub()
                }
            }

            function placeSub() {
                const sub = levelSub.item
                if (!sub || !levelRoot.hoveredRow)
                    return

                let pos
                let grid
                try {
                    pos = levelRoot.hoveredRow.mapToGlobal(0, 0)
                    grid = levelRoot.mapToGlobal(0, 0)
                } catch (e) {
                    return
                }

                const rowW = levelRoot.hoveredRow.width

                let sx = pos.x + rowW + 2
                let sy = pos.y + 2

                if (sx + sub.width > menuRoot.width - 4)
                    sx = pos.x - sub.width - 2

                const maxX = Math.max(4, menuRoot.width - sub.width - 4)
                const maxY = Math.max(4, menuRoot.height - sub.height - 4)

                levelSub.x = Math.round(Math.max(4, Math.min(sx, maxX)) - grid.x)
                levelSub.y = Math.round(Math.max(4, Math.min(sy, maxY)) - grid.y)
            }

            function setHovered(row) {
                if (!row)
                    return

                if (levelRoot.hoveredRow === row)
                    return

                levelRoot.hoveredEntry = row.modelData
                levelRoot.hoveredRow = row
                levelRoot.updateSub()
            }

            function updateSub() {
                if (
                    levelRoot.hoveredEntry &&
                    levelRoot.hoveredEntry.hasChildren
                ) {
                    if (levelSub.active)
                        levelSub.active = false

                    levelSub.sourceComponent = trayMenuLevel
                    levelSub.active = true
                } else {
                    levelSub.active = false
                }
            }
        }
    }

    // ── Root menu level ─────────────────────────────────────────────────

    Loader {
        id: rootLevelLoader

        active:
            menuRoot.visible

        sourceComponent: trayMenuLevel

        onLoaded: {
            const item = rootLevelLoader.item
            if (!item)
                return

            item.handle = menuRoot.openedHandle
            item.depth = 0

            item.widthChanged.connect(menuRoot.placeRoot)
            item.heightChanged.connect(menuRoot.placeRoot)

            menuRoot.placeRoot()
        }
    }
}

