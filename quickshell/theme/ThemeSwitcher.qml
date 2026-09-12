import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

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

    property bool searchActive: false
    property string searchText: ""
    property string searchFocusTarget: "list"
    property var displayedThemes: []

    property var pendingAction: null

    readonly property bool modalActive:
        pathEditorActive ||
        addThemeActive ||
        editorActive ||
        pendingAction !== null

    readonly property string previewedTheme:
        displayedThemes.length > 0 &&
        list.currentIndex >= 0 &&
        list.currentIndex < displayedThemes.length
            ? displayedThemes[list.currentIndex]
            : ThemeManager.currentTheme

    // ═════════════════════════════════════════════
    // Theme list
    // ═════════════════════════════════════════════

    function rebuildThemeList() {
        const query = searchText.trim().toLowerCase()
        const all = ThemeManager.paletteNames || []

        if (!query) {
            displayedThemes = all.slice()
        } else {
            displayedThemes = all.filter(function(key) {
                const entry = ThemeManager.palettes[key]

                const label = entry && entry.label
                    ? entry.label
                    : key

                return key.toLowerCase().indexOf(query) !== -1 ||
                       label.toLowerCase().indexOf(query) !== -1
            })
        }

        if (displayedThemes.length === 0) {
            list.currentIndex = -1
        } else {
            const currentKey =
                list.currentIndex >= 0 &&
                list.currentIndex < all.length
                    ? all[list.currentIndex]
                    : ThemeManager.currentTheme

            const preferredIndex =
                displayedThemes.indexOf(currentKey)

            list.currentIndex =
                preferredIndex >= 0
                    ? preferredIndex
                    : Math.max(
                        0,
                        Math.min(
                            list.currentIndex,
                            displayedThemes.length - 1
                        )
                    )
        }
    }

    function selectCurrent() {
        if (
            list.currentIndex < 0 ||
            list.currentIndex >= displayedThemes.length
        )
            return

        ThemeManager.setTheme(
            displayedThemes[list.currentIndex]
        )
    }

    function moveSelection(delta) {
        if (displayedThemes.length === 0)
            return

        const nextIndex = Math.max(
            0,
            Math.min(
                list.currentIndex + delta,
                displayedThemes.length - 1
            )
        )

        if (nextIndex === list.currentIndex)
            return

        list.currentIndex = nextIndex

        list.positionViewAtIndex(
            nextIndex,
            ListView.Center
        )
    }

    function centerCurrentTheme() {
        if (
            list.count === 0 ||
            list.currentIndex < 0
        )
            return

        Qt.callLater(function() {
            if (
                list.count > 0 &&
                list.currentIndex >= 0 &&
                list.currentIndex < list.count
            ) {
                list.positionViewAtIndex(
                    list.currentIndex,
                    ListView.Center
                )
            }
        })
    }

    function enterSearch() {
        searchActive = true
        searchFocusTarget = "input"

        searchInput.forceActiveFocus()
        searchInput.selectAll()
    }

    function exitSearch() {
        searchActive = false
        searchText = ""
        searchFocusTarget = "list"

        rebuildThemeList()

        const idx = displayedThemes.indexOf(
            ThemeManager.currentTheme
        )

        list.currentIndex =
            idx >= 0
                ? idx
                : 0

        centerCurrentTheme()

        focusItem.forceActiveFocus()
    }

    // Move keyboard focus from search to the theme cards.
    // Importantly, this does NOT apply the selected theme.
    function focusThemeList() {
        searchFocusTarget = "list"

        if (list.count > 0 && list.currentIndex < 0)
            list.currentIndex = 0

        centerCurrentTheme()

        focusItem.forceActiveFocus()
    }

    function focusSearchInput() {
        searchFocusTarget = "input"
        searchInput.forceActiveFocus()
    }

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
            pathEditorActive = false
            addThemeActive = false
            editorActive = false
            creatingTheme = false
            pendingAction = null

            searchActive = false
            searchText = ""
            searchFocusTarget = "list"

            rebuildThemeList()

            const idx = displayedThemes.indexOf(
                ThemeManager.currentTheme
            )

            list.currentIndex =
                idx >= 0
                    ? idx
                    : 0

            Qt.callLater(function() {
                centerCurrentTheme()
            })

            focusItem.forceActiveFocus()
        }
    }

    Connections {
        target: ThemeManager

        function onPaletteNamesChanged() {
            switcher.rebuildThemeList()
            switcher.centerCurrentTheme()
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

                if (switcher.editorActive)
                    return

                // ─────────────────────────────────
                // Escape
                // ─────────────────────────────────

                if (event.key === Qt.Key_Escape) {

                    if (switcher.pendingAction !== null) {
                        switcher.cancelPending()

                    } else if (switcher.addThemeActive) {
                        switcher.cancelAddTheme()

                    } else if (switcher.pathEditorActive) {
                        switcher.cancelPathEditor()

                    } else if (switcher.searchActive) {
                        switcher.exitSearch()

                    } else {
                        ThemeManager.hideSwitcher()
                    }

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Confirmation modal
                // ─────────────────────────────────

                if (switcher.pendingAction !== null) {

                    if (
                        event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter ||
                        event.key === Qt.Key_Y
                    ) {
                        switcher.confirmPending()
                        event.accepted = true

                    } else if (event.key === Qt.Key_N) {
                        switcher.cancelPending()
                        event.accepted = true
                    }

                    return
                }

                if (switcher.modalActive)
                    return

                // ─────────────────────────────────
                // Search → card navigation
                // ─────────────────────────────────

                if (
                    event.key === Qt.Key_Up &&
                    switcher.searchActive
                ) {
                    switcher.focusSearchInput()
                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Horizontal card navigation
                // ─────────────────────────────────

                if (
                    event.key === Qt.Key_Left ||
                    event.key === Qt.Key_H
                ) {
                    switcher.moveSelection(-1)
                    event.accepted = true
                    return
                }

                if (
                    event.key === Qt.Key_Right ||
                    event.key === Qt.Key_L
                ) {
                    switcher.moveSelection(1)
                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Home
                // ─────────────────────────────────

                if (event.key === Qt.Key_Home) {

                    if (list.count > 0) {
                        list.currentIndex = 0

                        list.positionViewAtIndex(
                            0,
                            ListView.Center
                        )
                    }

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // End
                // ─────────────────────────────────

                if (event.key === Qt.Key_End) {

                    if (list.count > 0) {

                        list.currentIndex =
                            list.count - 1

                        list.positionViewAtIndex(
                            list.count - 1,
                            ListView.Center
                        )
                    }

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Enter
                //
                // At this point focus is on the card
                // navigation layer, so Enter applies
                // the currently highlighted theme.
                //
                // Enter from the search field itself
                // is handled by searchInput below,
                // where it ONLY moves focus.
                // ─────────────────────────────────

                if (
                    event.key === Qt.Key_Return ||
                    event.key === Qt.Key_Enter
                ) {
                    switcher.selectCurrent()
                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Search
                // ─────────────────────────────────

                if (event.key === Qt.Key_S) {
                    switcher.enterSearch()
                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Palette path
                // ─────────────────────────────────

                if (event.key === Qt.Key_P) {
                    switcher.enterPathEditor()
                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Rescan
                // ─────────────────────────────────

                if (event.key === Qt.Key_R) {

                    ThemeManager.rescanPalettes()
                    switcher.rebuildThemeList()

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Edit
                // ─────────────────────────────────

                if (
                    event.key === Qt.Key_E &&
                    list.count > 0
                ) {

                    const key =
                        displayedThemes[
                            list.currentIndex
                        ]

                    if (key !== "auto")
                        switcher.requestEdit(key)

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Delete
                // ─────────────────────────────────

                if (
                    event.key === Qt.Key_D &&
                    list.count > 0
                ) {

                    const key =
                        displayedThemes[
                            list.currentIndex
                        ]

                    if (key !== "auto")
                        switcher.requestDelete(key)

                    event.accepted = true
                    return
                }

                // ─────────────────────────────────
                // Add
                // ─────────────────────────────────

                if (event.key === Qt.Key_A) {
                    switcher.enterAddTheme()
                    event.accepted = true
                    return
                }
            }
    }

    // ═════════════════════════════════════════════
    // Keyboard shortcuts
    // ═════════════════════════════════════════════

    Shortcut {
        sequence: "S"

        enabled:
            switcher.visible &&
            !switcher.searchActive &&
            !switcher.modalActive

        onActivated:
            switcher.enterSearch()
    }

    Shortcut {
        sequence: "P"

        enabled:
            switcher.visible &&
            !switcher.searchActive &&
            !switcher.modalActive

        onActivated:
            switcher.enterPathEditor()
    }

    Shortcut {
        sequence: "R"

        enabled:
            switcher.visible &&
            !switcher.searchActive &&
            !switcher.modalActive

        onActivated: {
            ThemeManager.rescanPalettes()
            switcher.rebuildThemeList()
        }
    }

    // ═════════════════════════════════════════════
    // Path editor
    // ═════════════════════════════════════════════

    function enterPathEditor() {
        pathEditorActive = true
        pathEditorText = ThemeManager.paletteDir

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
        pathEditorText = ThemeManager.paletteDir

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

        const name =
            addThemeText.trim()

        if (!name)
            return

        newThemeName = name
        addThemeText = name

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

        if (
            !themeKey ||
            themeKey === "auto"
        )
            return

        if (!ThemeManager.palettes[themeKey])
            return

        pendingAction = {
            type: "edit",
            themeKey: themeKey
        }

        focusItem.forceActiveFocus()
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

        if (
            !themeKey ||
            themeKey === "auto"
        )
            return

        if (!ThemeManager.palettes[themeKey])
            return

        pendingAction = {
            type: "delete",
            themeKey: themeKey
        }

        focusItem.forceActiveFocus()
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

            const key =
                pendingAction.themeKey

            if (
                key &&
                key !== "auto"
            ) {
                ThemeManager.deletePalette(key)
            }

            pendingAction = null

            switcher.rebuildThemeList()

            if (list.count > 0) {

                list.currentIndex =
                    Math.max(
                        0,
                        Math.min(
                            list.currentIndex,
                            list.count - 1
                        )
                    )

                switcher.centerCurrentTheme()
            }

            focusItem.forceActiveFocus()

            return
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
    // Main selector panel
    // ═════════════════════════════════════════════

    Item {
        id: panel

        anchors.centerIn: parent

        width:
            switcher.editorActive
                ? 1016
                : 996

        height:
            switcher.editorActive
                ? 616
                : 212

        // ─────────────────────────────────────────
        // Frame
        // ─────────────────────────────────────────

        Rectangle {
            id: frame

            anchors.fill: parent

            color:
                ThemeManager.surface

            border.width: 2

            border.color:
                ThemeManager.surfaceSecondary
        }

        // ─────────────────────────────────────────
        // Content
        // ─────────────────────────────────────────

        Item {
            id: contentArea

            anchors.fill: parent

            anchors.margins: 8

            // ═════════════════════════════════════
            // Embedded editor
            // ═════════════════════════════════════

            Column {
                anchors.fill: parent

                anchors.margins: 6

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
                        "Ctrl+S save  ·  Esc cancel"

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
                        parent.height - 62

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

                            else if (
                                rect.y + rect.height >
                                contentY + height
                            )
                                contentY =
                                    rect.y +
                                    rect.height -
                                    height

                            if (rect.x < contentX)
                                contentX = rect.x

                            else if (
                                rect.x + rect.width >
                                contentX + width
                            )
                                contentX =
                                    rect.x +
                                    rect.width -
                                    width
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

                            font.pixelSize: 14

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

                            onCursorRectangleChanged:
                                editorFlick.ensureVisible(
                                    cursorRectangle
                                )

                            Keys.onPressed:
                                function(event) {

                                    if (
                                        event.modifiers &
                                        Qt.ControlModifier &&
                                        event.key === Qt.Key_S
                                    ) {

                                        switcher.saveEditor()
                                        event.accepted = true
                                        return
                                    }

                                    if (
                                        event.key ===
                                        Qt.Key_Escape
                                    ) {

                                        switcher.cancelEditor()
                                        event.accepted = true
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

            // ═════════════════════════════════════
            // Selector
            // ═════════════════════════════════════

            Item {
                id: selector

                anchors.fill: parent

                anchors.margins: 6

                visible:
                    !switcher.editorActive

                // ═════════════════════════════════
                // Search
                // ═════════════════════════════════

                Rectangle {
                    id: searchBar

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    height: 42

                    color:
                        ThemeManager.backgroundSecondary

                    border.width: 1

                    border.color:
                        switcher.searchActive
                            ? ThemeManager.accent
                            : ThemeManager.surfaceSecondary

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12

                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: "⌕"

                        color:
                            ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize: 20
                    }

                    TextInput {
                        id: searchInput

                        anchors.left: parent.left
                        anchors.leftMargin: 38

                        anchors.right: parent.right
                        anchors.rightMargin: 12

                        anchors.verticalCenter:
                            parent.verticalCenter

                        height: parent.height

                        verticalAlignment:
                            TextInput.AlignVCenter

                        text:
                            switcher.searchText

                        color:
                            ThemeManager.text

                        selectionColor:
                            ThemeManager.accent

                        selectedTextColor:
                            ThemeManager.background

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontNormal

                        clip: true

                        readOnly:
                            !switcher.searchActive

                        activeFocusOnPress: true
                        selectByMouse: true

                        onTextChanged: {

                            if (
                                switcher.searchActive
                            ) {

                                switcher.searchText =
                                    text

                                switcher.rebuildThemeList()

                                list.currentIndex =
                                    list.count > 0
                                        ? 0
                                        : -1

                                switcher.centerCurrentTheme()
                            }
                        }

                        Keys.onPressed:
                            function(event) {

                                // ─────────────────
                                // Escape:
                                // leave search and
                                // restore full list
                                // ─────────────────

                                if (
                                    event.key ===
                                    Qt.Key_Escape
                                ) {

                                    switcher.exitSearch()
                                    event.accepted = true
                                    return
                                }

                                // ─────────────────
                                // Down:
                                // leave search and
                                // move focus to cards
                                // ─────────────────

                                if (
                                    event.key ===
                                    Qt.Key_Down
                                ) {

                                    switcher.focusThemeList()
                                    event.accepted = true
                                    return
                                }

                                // ─────────────────
                                // Enter:
                                // leave search and
                                // move focus to cards
                                //
                                // IMPORTANT:
                                // Do NOT call
                                // selectCurrent()
                                // here.
                                // ─────────────────

                                if (
                                    event.key ===
                                    Qt.Key_Return ||
                                    event.key ===
                                    Qt.Key_Enter
                                ) {

                                    switcher.focusThemeList()
                                    event.accepted = true
                                    return
                                }

                                // ─────────────────
                                // Up:
                                // keep focus in
                                // search field
                                // ─────────────────

                                if (
                                    event.key ===
                                    Qt.Key_Up
                                ) {

                                    event.accepted = true
                                    return
                                }
                            }
                    }

                    Text {
                        anchors.left:
                            searchInput.left

                        anchors.right:
                            searchInput.right

                        anchors.verticalCenter:
                            searchInput.verticalCenter

                        text:
                            "Search themes..."

                        color:
                            ThemeManager.textMuted

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontNormal

                        visible:
                            searchInput.text.length === 0

                        enabled: false
                        clip: true
                    }
                }

                // ═════════════════════════════════
                // Theme selector
                // ═════════════════════════════════

                ListView {
                    id: list

                    anchors.left: parent.left
                    anchors.right: parent.right

                    anchors.top:
                        searchBar.bottom

                    anchors.topMargin: 12

                    height: 130

                    orientation:
                        ListView.Horizontal

                    spacing: 12

                    clip: true

                    model:
                        switcher.displayedThemes

                    currentIndex: -1

                    keyNavigationEnabled: false

                    boundsBehavior:
                        Flickable.StopAtBounds

                    highlightMoveDuration: 300
                    highlightMoveVelocity: -1

                    preferredHighlightBegin:
                        (width - 220) / 2

                    preferredHighlightEnd:
                        (width + 220) / 2

                    highlightRangeMode:
                        ListView.StrictlyEnforceRange

                    snapMode:
                        ListView.SnapToItem

                    delegate: Rectangle {
                        id: card

                        required property int index
                        required property string modelData

                        readonly property bool isCursor:
                            index === list.currentIndex

                        readonly property bool isActive:
                            modelData ===
                            ThemeManager.currentTheme

                        readonly property string cardBackground:
                            ThemeManager.colorFor(
                                card.modelData,
                                "background"
                            )

                        readonly property string cardSurface:
                            ThemeManager.colorFor(
                                card.modelData,
                                "surface"
                            )

                        readonly property string cardText:
                            ThemeManager.colorFor(
                                card.modelData,
                                "text"
                            )

                        readonly property string cardMuted:
                            ThemeManager.colorFor(
                                card.modelData,
                                "textMuted"
                            )

                        width: 220
                        height: 130

                        color:
                            card.cardBackground

                        border.width:
                            card.isCursor
                                ? 2
                                : 1

                        border.color:
                            card.isCursor
                                ? ThemeManager.accent
                                : card.cardSurface

                        z:
                            card.isCursor
                                ? 2
                                : 1

                        // ═════════════════════════
                        // Active theme indicator
                        // ═════════════════════════

                        Rectangle {
                            width: 7
                            height: 7

                            anchors.top:
                                parent.top

                            anchors.topMargin: 10

                            anchors.right:
                                parent.right

                            anchors.rightMargin: 10

                            color:
                                card.isActive
                                    ? ThemeManager.accent
                                    : card.cardMuted

                            opacity:
                                card.isActive
                                    ? 1.0
                                    : 0.28

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180

                                    easing.type:
                                        Easing.OutCubic
                                }
                            }
                        }

                        // ═════════════════════════
                        // Mouse interaction
                        // ═════════════════════════

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {

                                list.currentIndex =
                                    card.index

                                list.positionViewAtIndex(
                                    card.index,
                                    ListView.Center
                                )

                                switcher.selectCurrent()

                                focusItem.forceActiveFocus()
                            }
                        }

                        // ═════════════════════════
                        // Theme color preview
                        // ═════════════════════════

                        Row {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            anchors.top:
                                parent.top

                            anchors.topMargin: 42

                            spacing: 5

                            Repeater {
                                model: [
                                    "accent",
                                    "accentSecondary",
                                    "success",
                                    "warning",
                                    "danger",
                                    "info"
                                ]

                                delegate: Rectangle {
                                    required property string modelData

                                    width: 18
                                    height: 18

                                    color:
                                        ThemeManager.colorFor(
                                            card.modelData,
                                            modelData
                                        )
                                }
                            }
                        }

                        // ═════════════════════════
                        // Theme name
                        // ═════════════════════════

                        Text {
                            anchors.left:
                                parent.left

                            anchors.right:
                                parent.right

                            anchors.bottom:
                                parent.bottom

                            anchors.bottomMargin: 14

                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            text:
                                card.modelData === "auto"
                                    ? "auto"
                                    : (
                                        ThemeManager
                                            .palettes[
                                                card.modelData
                                            ] &&
                                        ThemeManager
                                            .palettes[
                                                card.modelData
                                            ].label
                                            ? ThemeManager
                                                .palettes[
                                                    card.modelData
                                                ].label
                                            : card.modelData
                                    )

                            color:
                                card.cardText

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontNormal

                            font.weight:
                                card.isCursor
                                    ? ThemeManager.fontBold
                                    : ThemeManager.fontRegular

                            horizontalAlignment:
                                Text.AlignHCenter

                            elide:
                                Text.ElideRight
                        }
                    }
                }

                // ═════════════════════════════════
                // Add theme dialog
                // ═════════════════════════════════

                Rectangle {
                    id: addDialog

                    anchors.centerIn: parent

                    width: 430
                    height: 150

                    visible:
                        switcher.addThemeActive

                    z: 100

                    color:
                        ThemeManager.surface

                    border.width: 1

                    border.color:
                        ThemeManager.accent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18

                        spacing: 10

                        Text {
                            text: "Add theme"

                            color:
                                ThemeManager.text

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTitle

                            font.weight:
                                ThemeManager.fontBold
                        }

                        Rectangle {
                            width: parent.width
                            height: 38

                            color:
                                ThemeManager.backgroundDeep

                            border.width: 1

                            border.color:
                                addInput.activeFocus
                                    ? ThemeManager.accent
                                    : ThemeManager.surfaceSecondary

                            TextInput {
                                id: addInput

                                anchors.fill: parent
                                anchors.margins: 8

                                verticalAlignment:
                                    TextInput.AlignVCenter

                                color:
                                    ThemeManager.text

                                selectionColor:
                                    ThemeManager.accent

                                selectedTextColor:
                                    ThemeManager.background

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontNormal

                                text:
                                    switcher.addThemeText

                                selectByMouse: true
                                clip: true

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

                            Text {
                                anchors.left:
                                    parent.left

                                anchors.leftMargin: 8

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    "Theme name"

                                color:
                                    ThemeManager.textMuted

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontNormal

                                visible:
                                    addInput.text.length === 0

                                enabled: false
                            }
                        }

                        Text {
                            text:
                                "Enter to continue  ·  Esc to cancel"

                            color:
                                ThemeManager.textMuted

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontSmall
                        }
                    }
                }

                // ═════════════════════════════════
                // Palette path dialog
                // ═════════════════════════════════

                Rectangle {
                    id: pathDialog

                    anchors.centerIn: parent

                    width: 620
                    height: 150

                    visible:
                        switcher.pathEditorActive

                    z: 100

                    color:
                        ThemeManager.surface

                    border.width: 1

                    border.color:
                        ThemeManager.accent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18

                        spacing: 10

                        Text {
                            text:
                                "Palette path"

                            color:
                                ThemeManager.text

                            font.family:
                                ThemeManager.fontFamily

                            font.pixelSize:
                                ThemeManager.fontTitle

                            font.weight:
                                ThemeManager.fontBold
                        }

                        Rectangle {
                            width: parent.width
                            height: 38

                            color:
                                ThemeManager.backgroundDeep

                            border.width: 1

                            border.color:
                                pathInput.activeFocus
                                    ? ThemeManager.accent
                                    : ThemeManager.surfaceSecondary

                            TextInput {
                                id: pathInput

                                anchors.fill: parent
                                anchors.margins: 8

                                verticalAlignment:
                                    TextInput.AlignVCenter

                                color:
                                    ThemeManager.text

                                selectionColor:
                                    ThemeManager.accent

                                selectedTextColor:
                                    ThemeManager.background

                                font.family:
                                    ThemeManager.fontFamily

                                font.pixelSize:
                                    ThemeManager.fontNormal

                                text:
                                    switcher.pathEditorText

                                selectByMouse: true
                                clip: true

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

                        Text {
                            text:
                                "Enter to apply  ·  Esc to cancel"

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
        }
    }

    // ═════════════════════════════════════════════
    // Confirmation modal
    // ═════════════════════════════════════════════

    Rectangle {
        id: confirmation

        anchors.centerIn: parent

        width: 440

        height:
            switcher.pendingAction &&
            switcher.pendingAction.type === "delete"
                ? 170
                : 150

        visible:
            switcher.pendingAction !== null

        z: 1000

        color:
            ThemeManager.surface

        border.width: 1

        border.color:
            switcher.pendingAction &&
            switcher.pendingAction.type === "delete"
                ? ThemeManager.danger
                : ThemeManager.accent

        Column {
            anchors.fill: parent
            anchors.margins: 20

            spacing: 12

            Text {
                width: parent.width

                text: {

                    if (!switcher.pendingAction)
                        return ""

                    const key =
                        switcher.pendingAction.themeKey

                    const entry =
                        ThemeManager.palettes[key]

                    const label =
                        entry && entry.label
                            ? entry.label
                            : key

                    return switcher.pendingAction.type ===
                           "delete"
                        ? "Delete \u201c" + label + "\u201d?"
                        : "Edit \u201c" + label + "\u201d?"
                }

                color:
                    ThemeManager.text

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontTitle

                font.weight:
                    ThemeManager.fontBold

                horizontalAlignment:
                    Text.AlignHCenter
            }

            Text {
                width: parent.width

                visible:
                    switcher.pendingAction &&
                    switcher.pendingAction.type === "delete"

                text:
                    "This deletes the palette file permanently."

                color:
                    ThemeManager.textMuted

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontSmall

                horizontalAlignment:
                    Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                spacing: 8

                Rectangle {
                    width: 100
                    height: 34

                    color:
                        ThemeManager.backgroundSecondary

                    border.width: 1

                    border.color:
                        ThemeManager.surfaceSecondary

                    Text {
                        anchors.centerIn: parent

                        text:
                            "Cancel"

                        color:
                            ThemeManager.text

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontSmall
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked:
                            switcher.cancelPending()
                    }
                }

                Rectangle {
                    width: 100
                    height: 34

                    color:
                        switcher.pendingAction &&
                        switcher.pendingAction.type === "delete"
                            ? ThemeManager.danger
                            : ThemeManager.accent

                    border.width: 1

                    border.color:
                        color

                    Text {
                        anchors.centerIn: parent

                        text:
                            switcher.pendingAction &&
                            switcher.pendingAction.type === "delete"
                                ? "Delete"
                                : "Edit"

                        color:
                            ThemeManager.background

                        font.family:
                            ThemeManager.fontFamily

                        font.pixelSize:
                            ThemeManager.fontSmall

                        font.weight:
                            ThemeManager.fontBold
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked:
                            switcher.confirmPending()
                    }
                }
            }

            Text {
                width: parent.width

                text:
                    "Enter / Y confirm  ·  Esc / N cancel"

                color:
                    ThemeManager.textMuted

                font.family:
                    ThemeManager.fontFamily

                font.pixelSize:
                    ThemeManager.fontTiny

                horizontalAlignment:
                    Text.AlignHCenter
            }
        }
    }
}
