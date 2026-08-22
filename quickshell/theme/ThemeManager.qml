pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: manager

    // ═════════════════════════════════════════════
    // Palette directory — plain JSON files, not QML.
    // Change it with setPaletteDir(), same idea as
    // WallpaperPicker's wallpaperDir / "P" editor.
    // ═════════════════════════════════════════════

    property string paletteDir:
        "~/.config/quickshell/theme/palettes"

    property string currentTheme: "mocha"

    // Keyed by filename stem (mocha.json -> "mocha").
    // Each entry: { label, aliases, colors, semantic, path }
    property var palettes: ({})

    readonly property var paletteNames:
        Object.keys(palettes)

    readonly property var palette:
        palettes[currentTheme]
            ? palettes[currentTheme].colors
            : {}

    function colorFor(themeKey, role) {
        const entry = palettes[themeKey]
        if (!entry)
            return "#808080"
        const rawKey = entry.semantic ? entry.semantic[role] : role
        const value = entry.colors ? entry.colors[rawKey] : undefined
        return value || "#808080"
    }

    function _c(role) {
        return colorFor(currentTheme, role)
    }

    // ═════════════════════════════════════════════
    // Semantic colors
    // ═════════════════════════════════════════════

    readonly property color background:          _c("background")
    readonly property color backgroundSecondary: _c("backgroundSecondary")
    readonly property color backgroundDeep:      _c("backgroundDeep")

    readonly property color surface:          _c("surface")
    readonly property color surfaceSecondary: _c("surfaceSecondary")
    readonly property color surfaceTertiary:  _c("surfaceTertiary")

    readonly property color overlay:          _c("overlay")
    readonly property color overlaySecondary: _c("overlaySecondary")
    readonly property color overlayTertiary:  _c("overlayTertiary")

    readonly property color text:          _c("text")
    readonly property color textSecondary: _c("textSecondary")
    readonly property color textMuted:     _c("textMuted")

    readonly property color accent:          _c("accent")
    readonly property color accentSecondary: _c("accentSecondary")

    readonly property color success: _c("success")
    readonly property color warning: _c("warning")
    readonly property color danger:  _c("danger")
    readonly property color info:    _c("info")
    readonly property color peach:   _c("peach")
    readonly property color teal:    _c("teal")

    // ═════════════════════════════════════════════
    // Typography — unchanged
    // ═════════════════════════════════════════════

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontTiny: 10
    property int fontSmall: 11
    property int fontNormal: 13
    property int fontLarge: 15
    property int fontTitle: 18
    property int fontRegular: 400
    property int fontMedium: 500
    property int fontBold: 700
    property int fontHeavy: 800

    // ═════════════════════════════════════════════
    // Theme switching
    // ═════════════════════════════════════════════

    function setTheme(name) {
        const normalized = name.toLowerCase()
        for (const key in palettes) {
            if (palettes[key].aliases.indexOf(normalized) !== -1) {
                currentTheme = key
                return
            }
        }
        console.warn("ThemeManager: unknown theme:", name)
    }

    function nextTheme() {
        const names = paletteNames
        if (names.length === 0)
            return
        const index = names.indexOf(currentTheme)
        setTheme(names[(index + 1) % names.length])
    }

    // ═════════════════════════════════════════════
    // Palette directory scan — mirrors WallpaperPicker
    // ═════════════════════════════════════════════

    function rescanPalettes() {
        scanProc.running = true
    }

    function setPaletteDir(path) {
        const trimmed = path.trim()
        if (!trimmed)
            return
        paletteDir = trimmed
        rescanPalettes()
    }

    property Process scanProc: Process {
        id: scanProc
        command: [
            "bash",
            "-c",
            "dir=\"" +
            manager.paletteDir.replace(/^~/, "$HOME") +
            "\"; " +
            "for f in \"$dir\"/*.json; do " +
            "[ -f \"$f\" ] || continue; " +
            "echo \"###PALETTE_FILE### $f\"; " +
            "cat \"$f\"; " +
            "echo; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const chunks = this.text.split("###PALETTE_FILE### ")
                const found = {}

                for (const chunk of chunks) {
                    const trimmed = chunk.trim()
                    if (!trimmed)
                        continue

                    const nl = trimmed.indexOf("\n")
                    if (nl === -1)
                        continue

                    const filePath = trimmed.slice(0, nl).trim()
                    const jsonText = trimmed.slice(nl + 1)

                    let parsed
                    try {
                        parsed = JSON.parse(jsonText)
                    } catch (e) {
                        console.warn("ThemeManager: failed to parse", filePath, e)
                        continue
                    }

                    const stem = filePath
                        .split("/")
                        .pop()
                        .replace(/\.json$/i, "")
                        .toLowerCase()

                    found[stem] = {
                        label: parsed.label || stem,
                        aliases: parsed.aliases || [stem],
                        colors: parsed.colors || {},
                        semantic: parsed.semantic || {},
                        path: filePath
                    }
                }

                manager.palettes = found

                if (!found[manager.currentTheme]) {
                    const names = Object.keys(found)
                    if (names.length > 0)
                        manager.currentTheme = names[0]
                }
            }
        }
    }

    Component.onCompleted: rescanPalettes()

    // ═════════════════════════════════════════════
    // Switcher UI visibility
    // ═════════════════════════════════════════════

    property bool switcherVisible: false
    function toggleSwitcher() { switcherVisible = !switcherVisible }
    function showSwitcher() { switcherVisible = true }
    function hideSwitcher() { switcherVisible = false }

    // ═════════════════════════════════════════════
    // Editing / creating / deleting palettes
    // ═════════════════════════════════════════════

    property string editorCommand: "kitty -e nvim"

    property string _pendingEditPath: ""

    property Process editProc: Process {
        id: editProc
        onExited: manager.rescanPalettes()
    }

    property Process createProc: Process {
        id: createProc
        onExited: {
            manager.rescanPalettes()
            if (manager._pendingEditPath) {
                manager.launchEditor(manager._pendingEditPath)
                manager._pendingEditPath = ""
            }
        }
    }

    property Process deleteProc: Process {
        id: deleteProc
        onExited: manager.rescanPalettes()
    }

    function launchEditor(path) {
        const parts = editorCommand.split(" ")
        editProc.command = parts.concat([path])
        editProc.running = true
    }

    function editPalette(themeKey) {
        const entry = palettes[themeKey]
        if (!entry || !entry.path) {
            console.warn("ThemeManager: no file path for", themeKey)
            return
        }
        launchEditor(entry.path)
    }

    function deletePalette(themeKey) {
        const entry = palettes[themeKey]
        if (!entry || !entry.path) {
            console.warn("ThemeManager: no file path for", themeKey)
            return
        }
        deleteProc.command = [
            "bash", "-c",
            "rm -f \"" + entry.path.replace(/(["\\$`])/g, "\\$1") + "\""
        ]
        deleteProc.running = true
    }

    function createPalette(rawName) {
        const label = rawName.trim()
        const slug = label.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        if (!slug)
            return

        const templateJson = JSON.stringify({
            label: label || slug,
            aliases: [slug],
            colors: {
                base: "#1e1e2e", mantle: "#181825", crust: "#11111b",
                surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
                overlay0: "#6c7086", overlay1: "#7f849c", overlay2: "#9399b2",
                text: "#cdd6f4", subtext0: "#a6adc8", subtext1: "#bac2de",
                lavender: "#b4befe", mauve: "#cba6f7", red: "#f38ba8",
                green: "#a6e3a1", yellow: "#f9e2af", blue: "#89b4fa",
                peach: "#fab387", teal: "#94e2d5"
            },
            semantic: {
                background: "base", backgroundSecondary: "mantle", backgroundDeep: "crust",
                surface: "surface0", surfaceSecondary: "surface1", surfaceTertiary: "surface2",
                overlay: "overlay0", overlaySecondary: "overlay1", overlayTertiary: "overlay2",
                text: "text", textSecondary: "subtext1", textMuted: "subtext0",
                accent: "lavender", accentSecondary: "mauve",
                success: "green", warning: "yellow", danger: "red", info: "blue",
                peach: "peach", teal: "teal"
            }
        }, null, 2)

        const dir = paletteDir.replace(/^~/, "$HOME")
        const newPath = dir + "/" + slug + ".json"

        _pendingEditPath = newPath
        createProc.command = [
            "bash", "-c",
            "dir=\"" + dir + "\"; mkdir -p \"$dir\"; " +
            "cat > \"$dir/" + slug + ".json\" << 'EOF'\n" +
            templateJson + "\nEOF"
        ]
        createProc.running = true
    }
}
