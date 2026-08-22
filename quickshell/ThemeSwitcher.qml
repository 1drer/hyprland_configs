import QtQuick
import QtQuick.Layouts
import Quickshell
import "./theme"

PanelWindow {
    id: switcher

    visible: ThemeManager.switcherVisible
    focusable: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    property bool pathEditorActive: false
    property string pathEditorText: ""

    property bool addThemeActive: false
    property string addThemeText: ""

    // { type: "edit" | "delete", themeKey: string } or null
    property var pendingAction: null

    readonly property bool modalActive:
        pathEditorActive || addThemeActive || pendingAction !== null

    readonly property string previewedTheme:
        ThemeManager.paletteNames.length > 0
            ? ThemeManager.paletteNames[list.currentIndex]
            : ThemeManager.currentTheme

    function pc(role) {
        return ThemeManager.colorFor(previewedTheme, role)
    }

    function enterPathEditor() {
        pathEditorActive = true
        pathEditorText = ThemeManager.paletteDir
    }
    function applyPathEditor() {
        ThemeManager.setPaletteDir(pathEditorText)
        pathEditorActive = false
    }
    function cancelPathEditor() {
        pathEditorActive = false
        pathEditorText = ThemeManager.paletteDir
    }

    function enterAddTheme() {
        addThemeActive = true
        addThemeText = ""
    }
    function applyAddTheme() {
        ThemeManager.createPalette(addThemeText)
        addThemeActive = false
    }
    function cancelAddTheme() {
        addThemeActive = false
        addThemeText = ""
    }

    function requestEdit(themeKey) {
        pendingAction = { type: "edit", themeKey: themeKey }
    }
    function requestDelete(themeKey) {
        pendingAction = { type: "delete", themeKey: themeKey }
    }
    function confirmPending() {
        if (!pendingAction)
            return
        if (pendingAction.type === "edit")
            ThemeManager.editPalette(pendingAction.themeKey)
        else if (pendingAction.type === "delete")
            ThemeManager.deletePalette(pendingAction.themeKey)
        pendingAction = null
    }
    function cancelPending() {
        pendingAction = null
    }

    onVisibleChanged: {
        if (visible) {
            const idx = ThemeManager.paletteNames.indexOf(ThemeManager.currentTheme)
            list.currentIndex = idx >= 0 ? idx : 0
            pathEditorActive = false
            addThemeActive = false
            pendingAction = null
        }
    }

    // ═══════════════════════════════════════════════
    // Keyboard
    // ═══════════════════════════════════════════════

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (switcher.pendingAction !== null)
                switcher.cancelPending()
            else if (switcher.addThemeActive)
                switcher.cancelAddTheme()
            else if (switcher.pathEditorActive)
                switcher.cancelPathEditor()
            else
                ThemeManager.hideSwitcher()
        }
    }
    Shortcut {
        sequences: ["Return", "Enter", "Y"]
        enabled: switcher.pendingAction !== null
        onActivated: switcher.confirmPending()
    }
    Shortcut {
        sequence: "N"
        enabled: switcher.pendingAction !== null
        onActivated: switcher.cancelPending()
    }
    Shortcut {
        sequences: ["Down", "J"]
        enabled: !switcher.modalActive
        onActivated: {
            list.currentIndex =
                Math.min(list.currentIndex + 1, list.count - 1)
        }
    }
    Shortcut {
        sequences: ["Up", "K"]
        enabled: !switcher.modalActive
        onActivated: {
            list.currentIndex =
                Math.max(list.currentIndex - 1, 0)
        }
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: !switcher.modalActive && list.count > 0
        onActivated: {
            ThemeManager.setTheme(ThemeManager.paletteNames[list.currentIndex])
        }
    }
    Shortcut {
        sequence: "P"
        enabled: !switcher.modalActive
        onActivated: switcher.enterPathEditor()
    }
    Shortcut {
        sequence: "R"
        enabled: !switcher.modalActive
        onActivated: ThemeManager.rescanPalettes()
    }
    Shortcut {
        sequence: "E"
        enabled: !switcher.modalActive && list.count > 0
        onActivated: switcher.requestEdit(ThemeManager.paletteNames[list.currentIndex])
    }
    Shortcut {
        sequence: "D"
        enabled: !switcher.modalActive && list.count > 0
        onActivated: switcher.requestDelete(ThemeManager.paletteNames[list.currentIndex])
    }
    Shortcut {
        sequence: "A"
        enabled: !switcher.modalActive
        onActivated: switcher.enterAddTheme()
    }

    // ═══════════════════════════════════════════════
    // Backdrop
    // ═══════════════════════════════════════════════

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35
    }

    // ═══════════════════════════════════════════════
    // Centered panel
    // ═══════════════════════════════════════════════

    Item {
        id: panel
        anchors.centerIn: parent
        width: 820
        height: 460

        Rectangle {
            anchors.fill: parent
            z: -1
            color: ThemeManager.surface
            radius: 0
            border.width: 1
            border.color: ThemeManager.surfaceSecondary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // ═══════════════════════════════════════
            // Left: theme list
            // ═══════════════════════════════════════

            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                radius: 0
                color: ThemeManager.backgroundSecondary
                border.width: 1
                border.color: ThemeManager.surfaceSecondary

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // Path editor overlay
                    Rectangle {
                        width: parent.width
                        height: switcher.pathEditorActive ? 34 : 0
                        visible: switcher.pathEditorActive
                        clip: true
                        radius: 0
                        color: ThemeManager.backgroundDeep
                        border.width: 1
                        border.color: ThemeManager.accent

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment: TextInput.AlignVCenter
                            color: ThemeManager.text
                            font.family: ThemeManager.fontFamily
                            font.pixelSize: ThemeManager.fontTiny
                            clip: true
                            focus: switcher.pathEditorActive
                            selectByMouse: true
                            text: switcher.pathEditorText
                            onTextChanged: {
                                if (switcher.pathEditorActive)
                                    switcher.pathEditorText = text
                            }
                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    switcher.applyPathEditor()
                                    event.accepted = true
                                    break
                                case Qt.Key_Escape:
                                    switcher.cancelPathEditor()
                                    event.accepted = true
                                    break
                                }
                            }
                        }
                    }
                    // Add-theme overlay
                    Rectangle {
                        width: parent.width
                        height: switcher.addThemeActive ? 34 : 0
                        visible: switcher.addThemeActive
                        clip: true
                        radius: 0
                        color: ThemeManager.backgroundDeep
                        border.width: 1
                        border.color: ThemeManager.accent

                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment: Text.AlignVCenter
                            visible: switcher.addThemeText.length === 0
                            text: "Enter name"
                            color: ThemeManager.textMuted
                            font.family: ThemeManager.fontFamily
                            font.pixelSize: ThemeManager.fontTiny
                        }

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment: TextInput.AlignVCenter
                            color: ThemeManager.text
                            font.family: ThemeManager.fontFamily
                            font.pixelSize: ThemeManager.fontTiny
                            clip: true
                            focus: switcher.addThemeActive
                            selectByMouse: true
                            text: switcher.addThemeText
                            onTextChanged: {
                                if (switcher.addThemeActive)
                                    switcher.addThemeText = text
                            }
                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    switcher.applyAddTheme()
                                    event.accepted = true
                                    break
                                case Qt.Key_Escape:
                                    switcher.cancelAddTheme()
                                    event.accepted = true
                                    break
                                }
                            }
                        }
                    }

                    ListView {
                        id: list
                        width: parent.width
                        height: parent.height -
                            (switcher.pathEditorActive ? 42 : 0) -
                            (switcher.addThemeActive ? 42 : 0)
                        clip: true
                        model: ThemeManager.paletteNames
                        highlightFollowsCurrentItem: true
                        keyNavigationEnabled: false // handled via Shortcuts above

                        delegate: Rectangle {
                            id: row
                            required property int index
                            required property string modelData

                            readonly property bool isCursor:
                                index === list.currentIndex
                            readonly property bool isActive:
                                modelData === ThemeManager.currentTheme

                            width: list.width
                            height: 44
                            radius: 0
                            color: isCursor
                                ? ThemeManager.surfaceSecondary
                                : "transparent"
                            border.width: isActive ? 1 : 0
                            border.color: ThemeManager.accent

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: ThemeManager.palettes[row.modelData].label
                                    color: row.isActive
                                        ? ThemeManager.accent
                                        : ThemeManager.text
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontSmall
                                    font.weight: row.isActive
                                        ? ThemeManager.fontBold
                                        : ThemeManager.fontRegular
                                }

                                Row {
                                    spacing: 3
                                    Repeater {
                                        model: ["accent", "accentSecondary", "success", "warning", "danger"]
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: 12
                                            height: 12
                                            radius: 0
                                            color: ThemeManager.colorFor(row.modelData, modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════
            // Right: live mock preview
            // ═══════════════════════════════════════

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 0
                color: switcher.pc("background")
                border.width: 1
                border.color: switcher.pc("surfaceSecondary")

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 0
                        color: switcher.pc("backgroundDeep")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 0
                                color: switcher.pc("accent")
                            }
                            Text {
                                text: "Workspace 2"
                                color: switcher.pc("text")
                                font.family: ThemeManager.fontFamily
                                font.pixelSize: ThemeManager.fontSmall
                                Layout.leftMargin: 8
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "12:45 PM"
                                color: switcher.pc("textMuted")
                                font.family: ThemeManager.fontFamily
                                font.pixelSize: ThemeManager.fontSmall
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 110
                        radius: 0
                        color: switcher.pc("surface")
                        border.width: 1
                        border.color: switcher.pc("surfaceSecondary")

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "Battery"
                                    color: switcher.pc("text")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "82%"
                                    color: switcher.pc("success")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                    font.weight: ThemeManager.fontBold
                                }
                            }

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "Wi-Fi"
                                    color: switcher.pc("text")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "Connected"
                                    color: switcher.pc("info")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                }
                            }

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "Disk space"
                                    color: switcher.pc("text")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "Low"
                                    color: switcher.pc("danger")
                                    font.family: ThemeManager.fontFamily
                                    font.pixelSize: ThemeManager.fontNormal
                                    font.weight: ThemeManager.fontBold
                                }
                            }
                        }
                    }

                    Text {
                        text: ThemeManager.palettes[switcher.previewedTheme]
                            ? ThemeManager.palettes[switcher.previewedTheme].label
                            : ""
                        color: switcher.pc("textMuted")
                        font.family: ThemeManager.fontFamily
                        font.pixelSize: ThemeManager.fontTiny
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════
    // Confirmation modal — shared by edit + delete
    // ═══════════════════════════════════════════════
 

    Rectangle {
        anchors.centerIn: parent
        width: 820
        height: 460
        visible: switcher.pendingAction !== null
        z: 1000
        radius: 0
        color: ThemeManager.surface
        border.width: 1
        border.color:
            switcher.pendingAction && switcher.pendingAction.type === "delete"
                ? ThemeManager.danger
                : ThemeManager.accent

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width - 64

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: {
                    if (!switcher.pendingAction)
                        return ""
                    const key = switcher.pendingAction.themeKey
                    const entry = ThemeManager.palettes[key]
                    const label = entry ? entry.label : key
                    return switcher.pendingAction.type === "delete"
                        ? "Delete \u201c" + label + "\u201d?"
                        : "Edit \u201c" + label + "\u201d?"
                }
                color: ThemeManager.text
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontTitle
                font.weight: ThemeManager.fontBold
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: switcher.pendingAction && switcher.pendingAction.type === "delete"
                text: "This deletes the palette file permanently."
                color: ThemeManager.textMuted
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontSmall
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Enter / Y to confirm  ·  Esc / N to cancel"
                color: ThemeManager.textMuted
                font.family: ThemeManager.fontFamily
                font.pixelSize: ThemeManager.fontSmall
            }
        }
    }
  }
