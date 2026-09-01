import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
PanelWindow {
    id: switcher
    visible:
        ThemeManager.switcherVisible
    focusable: true
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    // ═════════════════════════════════════════════
    // State
    // ═════════════════════════════════════════════
    property bool pathEditorActive: false
    property string pathEditorText: ""
    property bool editorActive: false
    property bool creatingTheme: false
    property string editorThemeKey: ""
    property string editorText: ""
    property string newThemeName: ""
    property bool addThemeActive: false
    property string addThemeText: ""
    // { type: "edit" | "delete", themeKey: string }
    property var pendingAction: null
    readonly property bool modalActive:
        pathEditorActive ||
        addThemeActive ||
        editorActive ||
        pendingAction !== null
    readonly property string previewedTheme:
        ThemeManager.paletteNames.length > 0 &&
        list.currentIndex >= 0 &&
        list.currentIndex <
            ThemeManager.paletteNames.length 
            ? ThemeManager.paletteNames[
                list.currentIndex
            ]
            : ThemeManager.currentTheme
    function pc(role) {
        return ThemeManager.colorFor(
            previewedTheme,
            role
        )
    }
    // ═════════════════════════════════════════════
    // Visibility / focus
    // ═════════════════════════════════════════════
    onVisibleChanged: {
        if (visible) {
            const idx =
                ThemeManager.paletteNames.indexOf(
                    ThemeManager.currentTheme
                )
            list.currentIndex =
                idx >= 0
                    ? idx
                    : 0
            pathEditorActive = false
            addThemeActive = false
            editorActive = false
            creatingTheme = false
            pendingAction = null
            focusItem.forceActiveFocus()
        }
    }
    // ═════════════════════════════════════════════
    // Focus / keyboard handler
    // ═════════════════════════════════════════════
    Item {
        id: focusItem
        anchors.fill: parent
        focus:
            switcher.visible &&
            !switcher.editorActive
        Keys.onPressed:
            function(event) {
                // ─────────────────────────────
                // Editor
                // ─────────────────────────────
                if (switcher.editorActive)
                    return
                // ─────────────────────────────
                // Escape
                // ─────────────────────────────
                if (
                    event.key ===
                    Qt.Key_Escape
                ) {
                    if (
                        switcher.pendingAction !== null
                    ) {
                        switcher.cancelPending()
                    } else if (
                        switcher.addThemeActive
                    ) {
                        switcher.cancelAddTheme()
                    } else if (
                        switcher.pathEditorActive
                    ) {
                        switcher.cancelPathEditor()
                    } else {
                        ThemeManager.hideSwitcher()
                    }
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Confirmation
                // ─────────────────────────────
                if (
                    switcher.pendingAction !== null &&
                    (
                        event.key ===
                            Qt.Key_Return ||
                        event.key ===
                            Qt.Key_Enter ||
                        event.key ===
                            Qt.Key_Y
                    )
                ) {
                    switcher.confirmPending()
                    event.accepted = true
                    return
                }
                if (
                    switcher.pendingAction !== null &&
                    event.key === Qt.Key_N
                ) {
                    switcher.cancelPending()
                    event.accepted = true
                    return
                }
                if (switcher.modalActive)
                    return
                // ─────────────────────────────
                // Navigation
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_Down ||
                    event.key === Qt.Key_J
                ) {
                    if (list.count > 0) {
                        list.currentIndex =
                            Math.min(
                                list.currentIndex + 1,
                                list.count - 1
                            )
                    }
                    event.accepted = true
                    return
                }
                if (
                    event.key === Qt.Key_Up ||
                    event.key === Qt.Key_K
                ) {
                    if (list.count > 0) {
                        list.currentIndex =
                            Math.max(
                                list.currentIndex - 1,
                                0
                            )
                    }
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Select
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_Return ||
                    event.key === Qt.Key_Enter
                ) {
                    if (
                        list.count > 0
                    ) {
                        ThemeManager.setTheme(
                            ThemeManager.paletteNames[
                                list.currentIndex
                            ]
                        )
                    }
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Path
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_P
                ) {
                    switcher.enterPathEditor()
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Rescan
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_R
                ) {
                    ThemeManager.rescanPalettes()
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Edit (Auto is not editable)
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_E &&
                    list.count > 0
                ) {
                    const key =
                        ThemeManager.paletteNames[
                            list.currentIndex
                        ]
                    if (key !== "auto") {
                        switcher.requestEdit(key)
                    }
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Delete (Auto is not deletable)
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_D &&
                    list.count > 0
                ) {
                    const key =
                        ThemeManager.paletteNames[
                            list.currentIndex
                        ]
                    if (key !== "auto") {
                        switcher.requestDelete(key)
                    }
                    event.accepted = true
                    return
                }
                // ─────────────────────────────
                // Add
                // ─────────────────────────────
                if (
                    event.key === Qt.Key_A
                ) {
                    switcher.enterAddTheme()
                    event.accepted = true
                    return
                }
            }
    }
    // ═════════════════════════════════════════════
    // Path editor
    // ═════════════════════════════════════════════
    function enterPathEditor() {
        pathEditorActive = true
        pathEditorText =
            ThemeManager.paletteDir
        pathInput.forceActiveFocus()
    }
    function applyPathEditor() {
        ThemeManager.setPaletteDir(
            pathEditorText
        )
        pathEditorActive = false
        focusItem.forceActiveFocus()
    }
    function cancelPathEditor() {
        pathEditorActive = false
        pathEditorText =
            ThemeManager.paletteDir
        focusItem.forceActiveFocus()
    }
    // ═════════════════════════════════════════════
    // Add theme
    // ═════════════════════════════════════════════
    function enterAddTheme() {
        addThemeActive = true
        addThemeText = ""
        addInput.forceActiveFocus()
    }
    function applyAddTheme() {
        if (!addThemeText.trim())
            return
        newThemeName =
            addThemeText.trim()
        creatingTheme = true
        editorThemeKey = ""
        editorText =
            ThemeManager.defaultPaletteJson(
                newThemeName
            )
        addThemeActive = false
        editorActive = true
        editor.forceActiveFocus()
    }
    function cancelAddTheme() {
        addThemeActive = false
        addThemeText = ""
        focusItem.forceActiveFocus()
    }
    // ═════════════════════════════════════════════
    // Embedded editor
    // ═════════════════════════════════════════════
    function requestEdit(themeKey) {
        pendingAction = {
            type: "edit",
            themeKey: themeKey
        }
    }
    function openEditor(themeKey) {
        const entry =
            ThemeManager.palettes[themeKey]
        if (!entry) {
            console.warn(
                "ThemeSwitcher: theme not found:",
                themeKey
            )
            return
        }
        creatingTheme = false
        editorThemeKey = themeKey
        newThemeName = ""
        try {
            editorText =
                JSON.stringify(
                    {
                        label: entry.label,
                        aliases: entry.aliases,
                        colors: entry.colors,
                        semantic: entry.semantic
                    },
                    null,
                    2
                )
        } catch (e) {
            console.warn(
                "ThemeSwitcher: failed to prepare editor:",
                e
            )
            return
        }
        editorActive = true
        editor.forceActiveFocus()
    }
    function saveEditor() {
        const contents =
            editor.text
        // Validate JSON before writing.
        let parsed
        try {
            parsed =
                JSON.parse(contents)
        } catch (e) {
            editorError.text =
                "Invalid JSON — not saved"
            editorError.visible = true
            return
        }
        if (
            !parsed.colors ||
            typeof parsed.colors !== "object"
        ) {
            editorError.text =
                "Missing 'colors' object — not saved"
            editorError.visible = true
            return
        }
        editorError.visible = false
        if (creatingTheme) {
            if (!newThemeName.trim())
                return
            ThemeManager.saveNewPalette(
                newThemeName,
                contents
            )
        } else {
            if (!editorThemeKey)
                return
            ThemeManager.savePalette(
                editorThemeKey,
                contents
            )
        }
        editorActive = false
        creatingTheme = false
        editorThemeKey = ""
        newThemeName = ""
        focusItem.forceActiveFocus()
    }
    function cancelEditor() {
        editorActive = false
        creatingTheme = false
        editorThemeKey = ""
        newThemeName = ""
        editorError.visible = false
        focusItem.forceActiveFocus()
    }
    // ═════════════════════════════════════════════
    // Confirmation
    // ═════════════════════════════════════════════
    function requestDelete(themeKey) {
        pendingAction = {
            type: "delete",
            themeKey: themeKey
        }
    }
    function confirmPending() {
        if (!pendingAction)
            return
        if (
            pendingAction.type === "edit"
        ) {
            openEditor(
                pendingAction.themeKey
            )
        } else if (
            pendingAction.type === "delete"
        ) {
            ThemeManager.deletePalette(
                pendingAction.themeKey
            )
        }
        pendingAction = null
        if (!editorActive)
            focusItem.forceActiveFocus()
    }
    function cancelPending() {
        pendingAction = null
        focusItem.forceActiveFocus()
    }
    // ═════════════════════════════════════════════
    // Backdrop
    // ═════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.00
    }
    // ═════════════════════════════════════════════
    // Main selector
    // ═════════════════════════════════════════════
    Item {
        id: panel
        anchors.centerIn: parent
        width:
            switcher.editorActive
                ? 1000
                : 900
        height:
            switcher.editorActive
                ? 600
                : 560
        Rectangle {
            anchors.fill: parent
            color:
                ThemeManager.surface
            border.width: 1
            border.color:
                ThemeManager.surfaceSecondary
        }
        // ═════════════════════════════════════════
        // Embedded editor
        // ═════════════════════════════════════════
        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible:
                switcher.editorActive
            Text {
                width: parent.width
                text:
                    switcher.creatingTheme
                        ? "New Theme"
                        : (
                            ThemeManager
                                .palettes[
                                    switcher.editorThemeKey
                                ]
                                ? "Edit " +
                                  ThemeManager
                                    .palettes[
                                        switcher.editorThemeKey
                                    ].label
                                : "Edit Theme"
                        )
                color:
                    ThemeManager.text
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontTitle
                font.weight:
                    ThemeManager.fontBold
            }
            Text {
                width: parent.width
                text:
                    switcher.creatingTheme
                        ? "Ctrl+S save  ·  Esc cancel"
                        : "Ctrl+S save  ·  Esc cancel"
                color:
                    ThemeManager.textMuted
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontSmall
            }
            Rectangle {
                width: parent.width
                height:
                    parent.height -
                    62
                color:
                    ThemeManager.backgroundDeep
                border.width: 1
                border.color:
                    ThemeManager.surfaceSecondary
                Flickable {
                    id: editorFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth:
                        Math.max(
                            width,
                            editor.contentWidth
                        )
                    contentHeight:
                        Math.max(
                            height,
                            editor.contentHeight
                        )
                    function ensureVisible(rect) {
                        if (rect.y < contentY)
                            contentY = rect.y
                        else if (rect.y + rect.height > contentY + height)
                            contentY = rect.y + rect.height - height
                        if (rect.x < contentX)
                            contentX = rect.x
                        else if (rect.x + rect.width > contentX + width)
                            contentX = rect.x + rect.width - width
                    }
                    TextEdit {
                        id: editor
                        width:
                            Math.max(
                                editorFlick.width,
                                contentWidth
                            )
                        height:
                            Math.max(
                                editorFlick.height,
                                contentHeight
                            )
                        text:
                            switcher.editorText
                        color:
                            ThemeManager.text
                        selectionColor:
                            ThemeManager.accent
                        selectedTextColor:
                            ThemeManager.background
                        font.family:
                            ThemeManager.fontFamily
                        font.pixelSize:
                            14
                        wrapMode:
                            TextEdit.NoWrap
                        selectByMouse: true
                        cursorVisible: true
                        onTextChanged: {
                            if (
                                switcher.editorActive
                            ) {
                                switcher.editorText =
                                    text
                            }
                        }
                        onCursorRectangleChanged: {
                            editorFlick.ensureVisible(cursorRectangle)
                        }
                        Keys.onPressed:
                            function(event) {
                                // Ctrl+S
                                if (
                                    event.modifiers &
                                    Qt.ControlModifier &&
                                    event.key ===
                                    Qt.Key_S
                                ) {
                                    switcher.saveEditor()
                                    event.accepted =
                                        true
                                    return
                                }
                                // Escape
                                if (
                                    event.key ===
                                    Qt.Key_Escape
                                ) {
                                    switcher.cancelEditor()
                                    event.accepted =
                                        true
                                    return
                                }
                            }
                    }
                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded
                        }
                    ScrollBar.horizontal:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded
                        }
                }
            }
            Text {
                id: editorError
                width: parent.width
                visible: false
                color:
                    ThemeManager.danger
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontSmall
            }
        }
        // ═════════════════════════════════════════
        // Selector
        // ═════════════════════════════════════════
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            visible:
                !switcher.editorActive
            // ═════════════════════════════════════
            // Left
            // ═════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                color:
                    ThemeManager.backgroundSecondary
                border.width: 1
                border.color:
                    ThemeManager.surfaceSecondary
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    // ─────────────────────────────
                    // Path
                    // ─────────────────────────────
                    Rectangle {
                        width: parent.width
                        height:
                            switcher.pathEditorActive
                                ? 34
                                : 0
                        visible:
                            switcher.pathEditorActive
                        clip: true
                        color:
                            ThemeManager.backgroundDeep
                        border.width: 1
                        border.color:
                            ThemeManager.accent
                        TextInput {
                            id: pathInput
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment:
                                TextInput.AlignVCenter
                            color:
                                ThemeManager.text
                            font.family:
                                ThemeManager.fontFamily
                            font.pixelSize:
                                ThemeManager.fontNormal
                            clip: true
                            selectByMouse: true
                            text:
                                switcher.pathEditorText
                            onTextChanged: {
                                if (
                                    switcher.pathEditorActive
                                ) {
                                    switcher.pathEditorText =
                                        text
                                }
                            }
                            Keys.onPressed:
                                function(event) {
                                    if (
                                        event.key ===
                                            Qt.Key_Return ||
                                        event.key ===
                                            Qt.Key_Enter
                                    ) {
                                        switcher.applyPathEditor()
                                        event.accepted = true
                                    } else if (
                                        event.key ===
                                        Qt.Key_Escape
                                    ) {
                                        switcher.cancelPathEditor()
                                        event.accepted = true
                                    }
                                }
                        }
                    }
                    // ─────────────────────────────
                    // Add theme name
                    // ─────────────────────────────
                    Rectangle {
                        width: parent.width
                        height:
                            switcher.addThemeActive
                                ? 34
                                : 0
                        visible:
                            switcher.addThemeActive
                        clip: true
                        color:
                            ThemeManager.backgroundDeep
                        border.width: 1
                        border.color:
                            ThemeManager.accent
                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment:
                                Text.AlignVCenter
                            visible:
                                switcher.addThemeText.length === 0
                            text:
                                "Enter theme name"
                            color:
                                ThemeManager.textMuted
                            font.family:
                                ThemeManager.fontFamily
                            font.pixelSize:
                                ThemeManager.fontNormal
                        }
                        TextInput {
                            id: addInput
                            anchors.fill: parent
                            anchors.margins: 6
                            verticalAlignment:
                                TextInput.AlignVCenter
                            color:
                                ThemeManager.text
                            font.family:
                                ThemeManager.fontFamily
                            font.pixelSize:
                                ThemeManager.fontNormal
                            clip: true
                            selectByMouse: true
                            text:
                                switcher.addThemeText
                            onTextChanged: {
                                if (
                                    switcher.addThemeActive
                                ) {
                                    switcher.addThemeText =
                                        text
                                }
                            }
                            Keys.onPressed:
                                function(event) {
                                    if (
                                        event.key ===
                                            Qt.Key_Return ||
                                        event.key ===
                                            Qt.Key_Enter
                                    ) {
                                        switcher.applyAddTheme()
                                        event.accepted = true
                                    } else if (
                                        event.key ===
                                        Qt.Key_Escape
                                    ) {
                                        switcher.cancelAddTheme()
                                        event.accepted = true
                                    }
                                }
                        }
                    }
                    // ─────────────────────────────
                    // Theme list
                    // ─────────────────────────────
                    ListView {
                        id: list
                        width: parent.width
                        height:
                            parent.height -
                            (
                                switcher.pathEditorActive
                                    ? 42
                                    : 0
                            ) -
                            (
                                switcher.addThemeActive
                                    ? 42
                                    : 0
                            )
                        clip: true
                        model:
                            ThemeManager.paletteNames
                        keyNavigationEnabled:
                            false
                        delegate: Rectangle {
                            id: row
                            required property int index
                            required property string modelData
                            readonly property bool isCursor:
                                index ===
                                list.currentIndex
                            readonly property bool isActive:
                                modelData ===
                                ThemeManager.currentTheme
                            width:
                                list.width
                            height: 44
                            color:
                                isCursor
                                    ? ThemeManager.surfaceSecondary
                                    : "transparent"
                            border.width:
                                isActive ? 1 : 0
                            border.color:
                                ThemeManager.accent
                            Column {
                                anchors.left:
                                    parent.left
                                anchors.leftMargin:
                                    8
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                spacing: 4
                                Text {
                                    text:
                                        (
                                            row.modelData === "auto"
                                                ? "\u25C9 "
                                                : ""
                                        ) +
                                        ThemeManager
                                            .palettes[
                                                row.modelData
                                            ].label
                                    color:
                                        row.isActive
                                            ? ThemeManager.accent
                                            : ThemeManager.text
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                    font.weight:
                                        row.isActive
                                            ? ThemeManager.fontBold
                                            : ThemeManager.fontRegular
                                }
                                Text {
                                    visible:
                                        row.modelData === "auto"
                                    text:
                                        "follows current wallpaper"
                                    color:
                                        ThemeManager.textMuted
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontTiny
                                }
                                Row {
                                    visible:
                                        row.modelData !== "auto"
                                    spacing: 3
                                    Repeater {
                                        model: [
                                            "accent",
                                            "accentSecondary",
                                            "success",
                                            "warning",
                                            "danger"
                                        ]
                                        delegate:
                                            Rectangle {
                                                required property string modelData
                                                width: 12
                                                height: 12
                                                color:
                                                    ThemeManager.colorFor(
                                                        row.modelData,
                                                        modelData
                                                    )
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // ═════════════════════════════════════
            // Right preview
            // ═════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color:
                    switcher.pc("background")
                border.width: 1
                border.color:
                    switcher.pc(
                        "surfaceSecondary"
                    )
                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10
                    Rectangle {
                        width: parent.width
                        height: 34
                        color:
                            switcher.pc(
                                "backgroundDeep"
                            )
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Rectangle {
                                width: 10
                                height: 10
                                color:
                                    switcher.pc(
                                        "accent"
                                    )
                            }
                            Text {
                                text:
                                    "Workspace 2"
                                color:
                                    switcher.pc(
                                        "text"
                                    )
                                font.family:
                                    ThemeManager.fontFamily
                                font.pixelSize:
                                    ThemeManager.fontNormal
                                Layout.leftMargin: 8
                            }
                            Item {
                                Layout.fillWidth:
                                    true
                            }
                            Text {
                                text:
                                    "12:45 PM"
                                color:
                                    switcher.pc(
                                        "textMuted"
                                    )
                                font.family:
                                    ThemeManager.fontFamily
                                font.pixelSize:
                                    ThemeManager.fontNormal
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 120
                        color:
                            switcher.pc(
                                "surface"
                            )
                        border.width: 1
                        border.color:
                            switcher.pc(
                                "surfaceSecondary"
                            )
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            RowLayout {
                                width:
                                    parent.width
                                Text {
                                    text:
                                        "Battery"
                                    color:
                                        switcher.pc(
                                            "text"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                }
                                Item {
                                    Layout.fillWidth:
                                        true
                                }
                                Text {
                                    text:
                                        "82%"
                                    color:
                                        switcher.pc(
                                            "success"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                    font.weight:
                                        ThemeManager.fontBold
                                }
                            }
                            RowLayout {
                                width:
                                    parent.width
                                Text {
                                    text:
                                        "Wi-Fi"
                                    color:
                                        switcher.pc(
                                            "text"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                }
                                Item {
                                    Layout.fillWidth:
                                        true
                                }
                                Text {
                                    text:
                                        "Connected"
                                    color:
                                        switcher.pc(
                                            "info"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                }
                            }
                            RowLayout {
                                width:
                                    parent.width
                                Text {
                                    text:
                                        "Disk space"
                                    color:
                                        switcher.pc(
                                            "text"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                }
                                Item {
                                    Layout.fillWidth:
                                        true
                                }
                                Text {
                                    text:
                                        "Low"
                                    color:
                                        switcher.pc(
                                            "danger"
                                        )
                                    font.family:
                                        ThemeManager.fontFamily
                                    font.pixelSize:
                                        ThemeManager.fontNormal
                                    font.weight:
                                        ThemeManager.fontBold
                                }
                            }
                        }
                    }
                    Text {
                        text:
                            ThemeManager
                                .palettes[
                                    switcher.previewedTheme
                                ]
                                ? ThemeManager
                                    .palettes[
                                        switcher.previewedTheme
                                    ].label
                                : ""
                        color:
                            switcher.pc(
                                "textMuted"
                            )
                        font.family:
                            ThemeManager.fontFamily
                        font.pixelSize:
                            ThemeManager.fontNormal
                    }
                }
            }
        }
    }
    // ═════════════════════════════════════════════
    // Existing confirmation modal
    // ═════════════════════════════════════════════
    Rectangle {
        anchors.centerIn: parent
        width:
            switcher.editorActive
                ? 1000
                : 900
        height:
            switcher.editorActive
                ? 600
                : 560
        visible:
            switcher.pendingAction !== null
        z: 1000
        color:
            ThemeManager.surface
        border.width: 1
        border.color:
            switcher.pendingAction &&
            switcher.pendingAction.type ===
                "delete"
                ? ThemeManager.danger
                : ThemeManager.accent
        Column {
            anchors.centerIn: parent
            spacing: 12
            width:
                parent.width - 64
            Text {
                width: parent.width
                horizontalAlignment:
                    Text.AlignHCenter
                wrapMode:
                    Text.Wrap
                text: {
                    if (!switcher.pendingAction)
                        return ""
                    const key =
                        switcher.pendingAction
                            .themeKey
                    const entry =
                        ThemeManager.palettes[
                            key
                        ]
                    const label =
                        entry
                            ? entry.label
                            : key
                    return switcher
                        .pendingAction.type ===
                        "delete"
                        ? "Delete \u201c" +
                          label +
                          "\u201d?"
                        : "Edit \u201c" +
                          label +
                          "\u201d?"
                }
                color:
                    ThemeManager.text
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontTitle
                font.weight:
                    ThemeManager.fontBold
            }
            Text {
                width: parent.width
                horizontalAlignment:
                    Text.AlignHCenter
                wrapMode:
                    Text.Wrap
                visible:
                    switcher.pendingAction &&
                    switcher.pendingAction.type ===
                        "delete"
                text:
                    "This deletes the palette file permanently."
                color:
                    ThemeManager.textMuted
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontSmall
            }
            Text {
                width: parent.width
                horizontalAlignment:
                    Text.AlignHCenter
                text:
                    "Enter / Y to confirm  ·  Esc / N to cancel"
                color:
                    ThemeManager.textMuted
                font.family:
                    ThemeManager.fontFamily
                font.pixelSize:
                    ThemeManager.fontSmall
            }
        }
    }
}
