// WallpaperPicker.qml
//
// Keyboard-driven Quickshell wallpaper picker.
//
// KEYBOARD
//   ← / h            previous wallpaper
//   → / l            next wallpaper
//
//   Enter            apply selected wallpaper and close
//
//   s                search wallpapers
//   p                edit wallpaper folder
//   r                rescan wallpaper folder
//   f                fullscreen selected wallpaper
//
//   Esc              fullscreen -> picker
//                    path editor -> cancel
//                    search -> exit search
//                    picker -> close
//
//   ↑                search -> focus search field
//   ↓                search -> focus carousel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
Scope {
    id: root
    // ═══════════════════════════════════════════════════════════════════
    // Configuration
    // ═══════════════════════════════════════════════════════════════════
    property string wallpaperDir: "~/Pictures/Wallpapers"
    property var extensions: [
        "jpg",
        "jpeg",
        "png",
        "webp",
        "bmp"
    ]
    // ═══════════════════════════════════════════════════════════════════
    // Theme
    // ═══════════════════════════════════════════════════════════════════
    property QtObject theme: QtObject {
        // Surfaces
        property color base:     "#1e1e2e"
        property color mantle:   "#181825"
        property color crust:    "#11111b"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color overlay0: "#6c7086"
        // Text
        property color text:     "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color subtext1: "#bac2de"
        // Accent
        property color accent: "#b4befe"
        property color accentDim: Qt.rgba(
            0.706,
            0.746,
            0.996,
            0.45
        )
        property color danger: "#f38ba8"
        // ──────────────────────────────────────────────────────────────
        // Card geometry
        // ──────────────────────────────────────────────────────────────
        property int cardWidth: 230
        property int cardHeight: 360
        // Distance between card centers.
        property real cardSpacing: 270
        // Number of cards visible on each side.
        property int visibleRadius: 3
        // Center card scale.
        property real selectedScale: 1.14
        // ──────────────────────────────────────────────────────────────
        // Animation
        // ──────────────────────────────────────────────────────────────
        property int carouselDuration: 280
        property int borderIdle: 1
        property int borderCurrent: 2
        property int borderSelected: 3
    }
    // ═══════════════════════════════════════════════════════════════════
    // State
    // ═══════════════════════════════════════════════════════════════════
    property bool pickerVisible: false
    property string currentWallpaper: ""
    property var wallpapers: []
    property string filterText: ""
    property int selectedIndex: 0
    property bool searchActive: false
    property string searchFocusTarget: "input"
    property bool fullscreenActive: false
    property bool pathEditorActive: false
    property string pathEditorText: ""
    // ══════════════════════════════════════════════════════════════════
    // Carousel animation value
    //
    // This lives on root (which always exists) rather than on a
    // child of the LazyLoader-owned PanelWindow (which doesn't).
    // Everything that positions cards binds to this declaratively;
    // nothing ever needs to reach into the window's internals.
    // ══════════════════════════════════════════════════════════════════
    property real visualIndex: root.selectedIndex
    Behavior on visualIndex {
        NumberAnimation {
            duration: root.theme.carouselDuration
            easing.type: Easing.OutCubic
        }
    }
    // ═══════════════════════════════════════════════════════════════════
    // Derived State
    // ═══════════════════════════════════════════════════════════════════
    readonly property bool browsingEnabled:
        !root.fullscreenActive &&
        !root.pathEditorActive
    readonly property bool pickerActionsEnabled:
        !root.searchActive &&
        !root.pathEditorActive &&
        !root.fullscreenActive
    readonly property bool hasWallpapers:
        root.filteredWallpapers.length > 0
    readonly property var filteredWallpapers:
        root.filterText.length === 0
            ? root.wallpapers
            : root.filterWallpapers(
                root.wallpapers,
                root.filterText
            )
    // ═══════════════════════════════════════════════════════════════════
    // Filtering
    // ═══════════════════════════════════════════════════════════════════
    function filterWallpapers(list, query) {
        const search = query.toLowerCase();
        return list.filter(
            path => path.toLowerCase().includes(search)
        );
    }
    // ═══════════════════════════════════════════════════════════════════
    // Selection
    // ═══════════════════════════════════════════════════════════════════
    function clampSelection() {
        const count = root.filteredWallpapers.length;
        if (count === 0) {
            root.selectedIndex = 0;
            return;
        }
        root.selectedIndex = Math.max(
            0,
            Math.min(
                root.selectedIndex,
                count - 1
            )
        );
    }
    onFilteredWallpapersChanged: {
        root.clampSelection();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Navigation
    // ═══════════════════════════════════════════════════════════════════
    property real _lastMoveTime: 0
    readonly property int navThrottleMs: 45
    function moveSelection(delta) {
        const now = Date.now();
        if (
            now - root._lastMoveTime <
            root.navThrottleMs
        )
            return;
        root._lastMoveTime = now;
        const count =
            root.filteredWallpapers.length;
        if (count === 0)
            return;
        root.selectedIndex =
            (
                root.selectedIndex +
                delta +
                count
            ) % count;
    }
    function focusCurrentWallpaper() {
        if (!root.currentWallpaper) {
            root.selectedIndex = 0;
            return;
        }
        const index =
            root.filteredWallpapers.indexOf(
                root.currentWallpaper
            );
        root.selectedIndex =
            index >= 0
                ? index
                : 0;
    }
    // ═══════════════════════════════════════════════════════════════════
    // Picker State
    // ═══════════════════════════════════════════════════════════════════
    function resetPickerState() {
        root.searchActive = false;
        root.pathEditorActive = false;
        root.fullscreenActive = false;
        root.searchFocusTarget = "input";
        root.filterText = "";
    }
    function openPicker() {
        root.resetPickerState();
        root.pickerVisible = true;
        scanProc.running = true;
    }
    function closePicker() {
        root.pickerVisible = false;
    }
    function togglePicker() {
        if (root.pickerVisible)
            root.closePicker();
        else
            root.openPicker();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Search
    // ═══════════════════════════════════════════════════════════════════
    function enterSearch() {
        root.pathEditorActive = false;
        root.searchActive = true;
        root.searchFocusTarget = "input";
    }
    function exitSearch() {
        const selectedPath =
            root.filteredWallpapers[
                root.selectedIndex
            ];
        root.searchActive = false;
        root.searchFocusTarget = "input";
        root.filterText = "";
        const index =
            selectedPath !== undefined
                ? root.wallpapers.indexOf(
                    selectedPath
                  )
                : -1;
        root.selectedIndex =
            index >= 0
                ? index
                : 0;
    }
    // ═══════════════════════════════════════════════════════════════════
    // Path Editor
    // ═══════════════════════════════════════════════════════════════════
    function enterPathEditor() {
        root.searchActive = false;
        root.pathEditorActive = true;
        root.pathEditorText = root.wallpaperDir;
    }
    function applyPathEditor() {
        const path =
            root.pathEditorText.trim();
        if (!path)
            return;
        root.wallpaperDir = path;
        root.pathEditorActive = false;
        scanProc.running = true;
    }
    function cancelPathEditor() {
        root.pathEditorActive = false;
        root.pathEditorText =
            root.wallpaperDir;
    }
    // ═══════════════════════════════════════════════════════════════════
    // Wallpaper Selection
    // ═══════════════════════════════════════════════════════════════════
    function confirmSelection() {
        if (!root.hasWallpapers)
            return;
        const path =
            root.filteredWallpapers[
                root.selectedIndex
            ];
        root.applyWallpaper(path);
        root.closePicker();
    }
    // ═══════════════════════════════════════════════════════════════════
    // IPC
    // ═══════════════════════════════════════════════════════════════════
    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            root.togglePicker();
        }
        function open(): void {
            root.openPicker();
        }
        function close(): void {
            root.closePicker();
        }
    }
    // ═══════════════════════════════════════════════════════════════════
    // Wallpaper Scan
    // ═══════════════════════════════════════════════════════════════════
    Process {
        id: scanProc
        command: [
            "bash",
            "-c",
            "dir=\"" +
            root.wallpaperDir.replace(
                /^~/,
                "$HOME"
            ) +
            "\"; " +
            "find \"$dir\" -maxdepth 1 -type f \\( " +
            root.extensions
                .map(
                    e => "-iname '*." + e + "'"
                )
                .join(" -o ") +
            " \\) -printf '%T@ %p\\n' | " +
            "sort -rn | " +
            "cut -d' ' -f2-"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers =
                    this.text
                        .split("\n")
                        .filter(
                            path =>
                                path.trim().length > 0
                        );
                root.focusCurrentWallpaper();
            }
        }
    }
    // ═══════════════════════════════════════════════════════════════════
    // Current Wallpaper — awww
    // ═══════════════════════════════════════════════════════════════════
    Process {
        id: currentProc
        command: [
            "bash",
            "-c",
            "awww query 2>/dev/null | " +
            "grep -oP " +
            "'(?<=currently displaying: )\\S+|" +
            "(?<=image: ).*' | " +
            "head -n1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const path =
                    this.text.trim();
                if (path.length === 0)
                    return;
                root.currentWallpaper =
                    path;
                root.focusCurrentWallpaper();
            }
        }
        running: true
    }
    // ═══════════════════════════════════════════════════════════════════
    // Apply Wallpaper
    // ═══════════════════════════════════════════════════════════════════
    Process {
        id: applyProc
        stderr: StdioCollector {
            onStreamFinished: {
                const error =
                    this.text.trim();
                if (error.length > 0) {
                    console.warn(
                        "WallpaperPicker: apply failed ->",
                        error
                    );
                }
            }
        }
    }
    function applyWallpaper(path) {
        applyProc.command = [
            "bash",
            "-c",
            "pgrep -x awww-daemon >/dev/null || " +
            "(awww-daemon & sleep 0.3); " +
            "awww img " +
            "\"" + path.replace(/(["\\$`])/g, "\\$1") + "\" " +
            "--transition-type wipe " +
            "--transition-fps 60 " +
            "--transition-duration 1"
        ];
        applyProc.running = true;
        root.currentWallpaper =
            path;
    }
    // ═══════════════════════════════════════════════════════════════════
    // Startup
    // ═══════════════════════════════════════════════════════════════════
    Component.onCompleted: {
        scanProc.running = true;
    }
    // ═══════════════════════════════════════════════════════════════════
    // Window
    // ═══════════════════════════════════════════════════════════════════
    LazyLoader {
        id: windowLoader
        active:
            root.pickerVisible
        PanelWindow {
            id: win
            implicitWidth: 1920
            implicitHeight: 1080
            color:
                "transparent"
            focusable:
                true
            // ══════════════════════════════════════════════════════════
            // Keyboard Shortcuts
            // ══════════════════════════════════════════════════════════
            Shortcut {
                sequence:
                    "Escape"
                onActivated: {
                    if (root.fullscreenActive) {
                        root.fullscreenActive =
                            false;
                    } else if (
                        root.pathEditorActive
                    ) {
                        root.cancelPathEditor();
                    } else if (
                        root.searchActive
                    ) {
                        root.exitSearch();
                    } else {
                        root.closePicker();
                    }
                }
            }
            Shortcut {
                sequence:
                    "F"
                    enabled:
                    root.fullscreenActive ||
                    (root.pickerActionsEnabled && root.hasWallpapers)
                    onActivated: {
                      root.fullscreenActive = !root.fullscreenActive;
                    }
            }
            Shortcut {
                sequences: [
                    "Return",
                    "Enter"
                ]
                enabled:
                    !root.pathEditorActive &&
                    !root.fullscreenActive &&
                    root.hasWallpapers &&
                    !(
                        root.searchActive &&
                        root.searchFocusTarget ===
                        "input"
                    )
                onActivated: {
                    root.confirmSelection();
                }
            }
            Shortcut {
                sequences: [
                    "Left",
                    "H"
                ]
                enabled:
                    root.browsingEnabled &&
                    (
                        !root.searchActive ||
                        root.searchFocusTarget ===
                        "list"
                    )
                onActivated: {
                    root.moveSelection(-1);
                }
            }
            Shortcut {
                sequences: [
                    "Right",
                    "L"
                ]
                enabled:
                    root.browsingEnabled &&
                    (
                        !root.searchActive ||
                        root.searchFocusTarget ===
                        "list"
                    )
                onActivated: {
                    root.moveSelection(1);
                }
            }
            Shortcut {
                sequence:
                    "S"
                enabled:
                    root.pickerActionsEnabled
                onActivated: {
                    root.enterSearch();
                }
            }
            Shortcut {
                sequence:
                    "P"
                enabled:
                    root.pickerActionsEnabled
                onActivated: {
                    root.enterPathEditor();
                }
            }
            Shortcut {
                sequence:
                    "R"
                enabled:
                    root.pickerActionsEnabled
                onActivated: {
                    scanProc.running = true;
                }
            }
            Shortcut {
                sequence:
                    "Up"
                enabled:
                    root.searchActive
                onActivated: {
                    root.searchFocusTarget =
                        "input";
                }
            }
            Shortcut {
                sequence:
                    "Down"
                enabled:
                    root.searchActive
                onActivated: {
                    root.searchFocusTarget =
                        "list";
                }
            }
            // ══════════════════════════════════════════════════════════
            // Content
            // ══════════════════════════════════════════════════════════
            Item {
                id: content
                anchors.fill:
                    parent
                readonly property int headerHeight:
                    74
                // ══════════════════════════════════════════════════════
                // Filmstrip
                // ══════════════════════════════════════════════════════
                Item {
                    id: filmstrip
                    anchors {
                        top:
                            parent.top
                        topMargin:
                            content.headerHeight
                        left:
                            parent.left
                        right:
                            parent.right
                        bottom:
                            parent.bottom
                    }
                    clip:
                        true
                    readonly property real centerX:
                        width / 2
                    readonly property real centerY:
                        height / 2
                    // ══════════════════════════════════════════════════
                    // Search dimming
                    // ══════════════════════════════════════════════════
                    opacity:
                        root.searchActive &&
                        root.searchFocusTarget ===
                        "input"
                            ? 0.35
                            : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration:
                                160
                            easing.type:
                                Easing.OutCubic
                        }
                    }
                    // ══════════════════════════════════════════════════
                    // Empty State
                    // ══════════════════════════════════════════════════
                    Column {
                        anchors.centerIn:
                            parent
                        visible:
                            root.wallpapers.length ===
                            0
                        spacing:
                            6
                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter
                            text:
                                "No wallpapers found"
                            color:
                                root.theme.subtext0
                            font.pixelSize:
                                15
                        }
                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter
                            text:
                                root.wallpaperDir
                            color:
                                root.theme.overlay0
                            font.pixelSize:
                                12
                        }
                    }
                    // ══════════════════════════════════════════════════
                    // No Matches
                    // ══════════════════════════════════════════════════
                    Text {
                        anchors.centerIn:
                            parent
                        visible:
                            root.wallpapers.length > 0 &&
                            root.filteredWallpapers.length === 0
                        text:
                            "No matches for \u201c" +
                            root.filterText +
                            "\u201d"
                        color:
                            root.theme.subtext0
                        font.pixelSize:
                            14
                    }
                    // ══════════════════════════════════════════════════
                    // Wallpaper Cards
                    // ══════════════════════════════════════════════════
                    Repeater {
                        model:
                            root.filteredWallpapers
                        delegate: Item {
                            id: card
                            required property int index
                            required property string modelData
                            // ──────────────────────────────────────────
                            // Distance from visual center.
                            //
                            // Bound to root.visualIndex, which lives
                            // on the always-present Scope rather than
                            // on a child of the lazily-loaded window.
                            // ──────────────────────────────────────────
                            readonly property real distance:
                                index -
                                root.visualIndex
                            readonly property real absDistance:
                                Math.abs(distance)
                            readonly property bool isSelected:
                                index ===
                                root.selectedIndex
                            readonly property bool isCurrent:
                                modelData ===
                                root.currentWallpaper
                            readonly property bool nearby:
                                absDistance <=
                                root.theme.visibleRadius +
                                0.5
                            // ──────────────────────────────────────────
                            // Scale
                            //
                            // Only the center card grows.
                            //
                            // Its layout width remains exactly the same,
                            // so the center point never moves.
                            // ──────────────────────────────────────────
                            readonly property real centerInfluence:
                                Math.max(
                                    0,
                                    1 - absDistance
                                )
                            readonly property real visualScale:
                                1 +
                                (
                                    root.theme.selectedScale -
                                    1
                                ) *
                                centerInfluence
                            width:
                                root.theme.cardWidth
                            height:
                                root.theme.cardHeight
                            // ══════════════════════════════════════════
                            // POSITION
                            //
                            // This is entirely derived from
                            // root.visualIndex.
                            //
                            // The selected card is always:
                            //
                            // centerX - cardWidth / 2
                            //
                            // There is no animated x property.
                            // ══════════════════════════════════════════
                            x:
                                filmstrip.centerX -
                                width / 2 +
                                (
                                    distance *
                                    root.theme.cardSpacing
                                )
                            y:
                                filmstrip.centerY -
                                height / 2
                            visible:
                                nearby
                            z:
                                1000 -
                                absDistance +
                                (
                                    isSelected
                                        ? 500
                                        : 0
                                )
                            // ══════════════════════════════════════════
                            // OPACITY
                            //
                            // IMPORTANT:
                            //
                            // There is NO Behavior on opacity.
                            //
                            // opacity is driven directly by distance,
                            // which itself comes from root.visualIndex.
                            //
                            // Therefore:
                            //
                            // movement + scale + opacity
                            //
                            // all follow exactly the same animation.
                            // ══════════════════════════════════════════
                            opacity:
                                nearby
                                    ? Math.max(
                                        0.32,
                                        1 -
                                        absDistance *
                                        0.16
                                    )
                                    : 0
                            // ══════════════════════════════════════════
                            // Card Visual
                            // ══════════════════════════════════════════
                            Item {
                                id: cardVisual
                                anchors.centerIn:
                                    parent
                                width:
                                    root.theme.cardWidth
                                height:
                                    root.theme.cardHeight
                                scale:
                                    card.visualScale
                                // ──────────────────────────────────────
                                // Background
                                // ──────────────────────────────────────
                                Rectangle {
                                    anchors.fill:
                                        parent
                                    color:
                                        root.theme.surface0
                                }
                                // ──────────────────────────────────────
                                // Thumbnail
                                // ──────────────────────────────────────
                                Image {
                                    id: thumb
                                    anchors.fill:
                                        parent
                                    source:
                                        card.nearby
                                            ? (
                                                "file://" +
                                                card.modelData
                                              )
                                            : ""
                                    fillMode:
                                        Image.PreserveAspectCrop
                                    asynchronous:
                                        true
                                    cache:
                                        true
                                    sourceSize {
                                        width:
                                            root.theme.cardWidth *
                                            1.6
                                        height:
                                            root.theme.cardHeight *
                                            1.6
                                    }
                                    Rectangle {
                                        anchors.fill:
                                            parent
                                        visible:
                                            thumb.status !==
                                            Image.Ready
                                        color:
                                            root.theme.crust
                                    }
                                }
                                // ──────────────────────────────────────
                                // Non-selected overlay
                                // ──────────────────────────────────────
                                Rectangle {
                                    anchors.fill:
                                        parent
                                    color:
                                        root.theme.crust
                                    opacity:
                                        card.isSelected
                                            ? 0
                                            : 0.28
                                }
                                // ──────────────────────────────────────
                                // Border
                                // ──────────────────────────────────────
                                Rectangle {
                                    anchors.fill:
                                        parent
                                    color:
                                        "transparent"
                                    border.width:
                                        card.isSelected
                                            ? root.theme.borderSelected
                                            : (
                                                card.isCurrent
                                                    ? root.theme.borderCurrent
                                                    : root.theme.borderIdle
                                              )
                                    border.color:
                                        card.isSelected
                                            ? root.theme.accent
                                            : (
                                                card.isCurrent
                                                    ? root.theme.accentDim
                                                    : root.theme.surface1
                                              )
                                }
                            }
                        }
                    }
                }
                // ══════════════════════════════════════════════════════
                // Search Bar
                // ══════════════════════════════════════════════════════
                Rectangle {
                    id: searchOverlay
                    anchors {
                        horizontalCenter:
                            parent.horizontalCenter
                        top:
                            parent.top
                        topMargin:
                            26
                    }
                    width:
                        460
                    height:
                        48
                    visible:
                        root.searchActive
                    z:
                        10000
                    color:
                        root.theme.mantle
                    border.width:
                        root.searchFocusTarget ===
                        "input"
                            ? 2
                            : 1
                    border.color:
                        root.searchFocusTarget ===
                        "input"
                            ? root.theme.accent
                            : root.theme.surface1
                    RowLayout {
                        anchors {
                            fill:
                                parent
                            leftMargin:
                                16
                            rightMargin:
                                16
                        }
                        spacing:
                            10
                        Text {
                            text:
                                "Search"
                            color:
                                root.theme.subtext0
                            font.pixelSize:
                                13
                        }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth:
                                true
                            verticalAlignment:
                                TextInput.AlignVCenter
                            color:
                                root.theme.text
                            font.pixelSize:
                                14
                            clip:
                                true
                            focus:
                                root.searchActive &&
                                root.searchFocusTarget ===
                                "input"
                            cursorVisible:
                                activeFocus
                            selectByMouse:
                                true
                            onTextChanged: {
                                root.filterText =
                                    text;
                            }
                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    root.exitSearch();
                                    event.accepted =
                                        true;
                                    break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    root.searchFocusTarget =
                                        "list";
                                    event.accepted =
                                        true;
                                    break;
                                case Qt.Key_Up:
                                    root.searchFocusTarget =
                                        "input";
                                    event.accepted =
                                        true;
                                    break;
                                case Qt.Key_Down:
                                    root.searchFocusTarget =
                                        "list";
                                    event.accepted =
                                        true;
                                    break;
                                }
                            }
                        }
                    }
                }
                // ══════════════════════════════════════════════════════
                // Path Editor
                // ══════════════════════════════════════════════════════
                Rectangle {
                    id: pathOverlay
                    anchors {
                        horizontalCenter:
                            parent.horizontalCenter
                        top:
                            parent.top
                        topMargin:
                            26
                    }
                    width:
                        620
                    height:
                        48
                    visible:
                        root.pathEditorActive
                    z:
                        10000
                    color:
                        root.theme.mantle
                    border.width:
                        2
                    border.color:
                        root.theme.accent
                    RowLayout {
                        anchors {
                            fill:
                                parent
                            leftMargin:
                                16
                            rightMargin:
                                16
                        }
                        spacing:
                            10
                        Text {
                            text:
                                "Path"
                            color:
                                root.theme.subtext0
                            font.pixelSize:
                                13
                        }
                        TextInput {
                            id: pathInput
                            Layout.fillWidth:
                                true
                            verticalAlignment:
                                TextInput.AlignVCenter
                            color:
                                root.theme.text
                            font.pixelSize:
                                14
                            clip:
                                true
                            focus:
                                root.pathEditorActive
                            cursorVisible:
                                activeFocus
                            selectByMouse:
                                true
                            text:
                                root.pathEditorText
                            onTextChanged: {
                                if (
                                    root.pathEditorActive
                                ) {
                                    root.pathEditorText =
                                        text;
                                }
                            }
                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    root.applyPathEditor();
                                    event.accepted =
                                        true;
                                    break;
                                case Qt.Key_Escape:
                                    root.cancelPathEditor();
                                    event.accepted =
                                        true;
                                    break;
                                }
                            }
                        }
                    }
                }
                // ══════════════════════════════════════════════════════
                // Fullscreen Preview
                // ══════════════════════════════════════════════════════
                Item {
                    id: fullscreenOverlay
                    anchors.fill:
                        parent
                    visible:
                        root.fullscreenActive
                    z:
                        20000
                    Image {
                        id: fullscreenImage
                        anchors.centerIn:
                            parent
                        property real imageAspectRatio:
                            sourceSize.width > 0 &&
                            sourceSize.height > 0
                                ? (
                                    sourceSize.width /
                                    sourceSize.height
                                  )
                                : 16 / 9
                        width:
                            Math.min(
                                parent.width - 48,
                                (
                                    parent.height - 48
                                ) *
                                imageAspectRatio
                            )
                        height:
                            Math.min(
                                parent.height - 48,
                                (
                                    parent.width - 48
                                ) /
                                imageAspectRatio
                            )
                        fillMode:
                            Image.PreserveAspectFit
                        asynchronous:
                            true
                        source:
                            root.fullscreenActive &&
                            root.hasWallpapers
                                ? (
                                    "file://" +
                                    root.filteredWallpapers[
                                        root.selectedIndex
                                    ]
                                  )
                                : ""
                        Rectangle {
                            anchors.fill:
                                parent
                            color:
                                "transparent"
                            border.width:
                                3
                            border.color:
                                root.theme.accent
                            visible:
                                fullscreenImage.status ===
                                Image.Ready
                        }
                    }
                }
            }
        }
    }
}
// ═══════════════════════════════════════════════════════════════════════
// Minimal standalone shell.qml
// ═══════════════════════════════════════════════════════════════════════
//
// import Quickshell
//
// ShellRoot {
//     WallpaperPicker {}
// }
//
// Run:
//
//   quickshell -p /path/to/that/shell.qml
//
// Toggle:
//
//   qs ipc call wallpaper toggle

