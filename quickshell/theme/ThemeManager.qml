pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: manager

    // ═════════════════════════════════════════════
    // Palette state
    // ═════════════════════════════════════════════

    property string paletteDir:
        "~/.config/quickshell/theme/palettes"

    property string currentTheme: "mocha"

    property var palettes: ({})
    property var paletteNames: []
    property var themeAliases: ({})

    readonly property var palette:
        palettes[currentTheme]
            ? palettes[currentTheme].colors
            : {}

    // ═════════════════════════════════════════════
    // Color lookup
    // ═════════════════════════════════════════════

    function colorFor(themeKey, role) {
        const entry = palettes[themeKey]

        if (!entry || !entry.colors)
            return "#808080"

        return entry.colors[role] || "#808080"
    }

    function _c(role) {
        return colorFor(currentTheme, role)
    }

    // ═════════════════════════════════════════════
    // Semantic colors
    // ═════════════════════════════════════════════

    readonly property color background:
        _c("background")

    readonly property color backgroundSecondary:
        _c("backgroundSecondary")

    readonly property color backgroundDeep:
        _c("backgroundDeep")

    readonly property color surface:
        _c("surface")

    readonly property color surfaceSecondary:
        _c("surfaceSecondary")

    readonly property color surfaceTertiary:
        _c("surfaceTertiary")

    readonly property color overlay:
        _c("overlay")

    readonly property color overlaySecondary:
        _c("overlaySecondary")

    readonly property color overlayTertiary:
        _c("overlayTertiary")

    readonly property color text:
        _c("text")

    readonly property color textSecondary:
        _c("textSecondary")

    readonly property color textMuted:
        _c("textMuted")

    readonly property color accent:
        _c("accent")

    readonly property color accentSecondary:
        _c("accentSecondary")

    readonly property color success:
        _c("success")

    readonly property color warning:
        _c("warning")

    readonly property color danger:
        _c("danger")

    readonly property color info:
        _c("info")

    // ═════════════════════════════════════════════
    // Typography
    // ═════════════════════════════════════════════

    property string fontFamily:
        "JetBrainsMono Nerd Font"

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
    // Persistent current theme
    // ═════════════════════════════════════════════

    property Process saveCurrentProc: Process {
        id: saveCurrentProc

        stderr: StdioCollector {
            onStreamFinished: {
                const err = this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: saveCurrentTheme failed ->",
                        err
                    )
            }
        }
    }

    function saveCurrentTheme() {
        const dir =
            paletteDir.replace(/^~/, "$HOME")

        saveCurrentProc.command = [
            "bash",
            "-c",
            "mkdir -p \"" +
            dir +
            "\" && printf '%s\\n' \"$1\" > \"" +
            dir +
            "/current\"",
            "bash",
            currentTheme
        ]

        saveCurrentProc.running = true
    }

    property Process loadCurrentProc: Process {
        id: loadCurrentProc

        stdout: StdioCollector {
            onStreamFinished: {
                const saved =
                    this.text.trim().toLowerCase()

                if (!saved)
                    return

                if (manager.themeAliases[saved]) {
                    manager.currentTheme =
                        manager.themeAliases[saved]

                    manager.applyExternalTheme(
                        manager.currentTheme
                    )
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const err = this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: loadCurrentTheme failed ->",
                        err
                    )
            }
        }
    }

    function loadCurrentTheme() {
        const dir =
            paletteDir.replace(/^~/, "$HOME")

        loadCurrentProc.command = [
            "bash",
            "-c",
            "if [ -f \"" +
            dir +
            "/current\" ]; then cat \"" +
            dir +
            "/current\"; fi"
        ]

        loadCurrentProc.running = true
    }

    // ═════════════════════════════════════════════
    // Theme switching
    // ═════════════════════════════════════════════

    function setTheme(name) {
        const normalized =
            String(name).toLowerCase()

        const key =
            themeAliases[normalized]

        if (!key) {
            console.warn(
                "ThemeManager: unknown theme:",
                name
            )
            return
        }

        currentTheme = key

        applyExternalTheme(key)
        saveCurrentTheme()
    }

    function nextTheme() {
        if (paletteNames.length === 0)
            return

        const index =
            paletteNames.indexOf(currentTheme)

        const nextIndex =
            index < 0
                ? 0
                : (index + 1) %
                  paletteNames.length

        currentTheme =
            paletteNames[nextIndex]

        applyExternalTheme(currentTheme)
        saveCurrentTheme()
    }

    // ═════════════════════════════════════════════
    // Palette parsing
    // ═════════════════════════════════════════════

    function parsePalette(filePath, parsed) {
        const stem =
            filePath
                .split("/")
                .pop()
                .replace(
                    /\.json$/i,
                    ""
                )
                .toLowerCase()

        let aliases =
            parsed.aliases ?? []

        if (!Array.isArray(aliases))
            aliases = [aliases]

        aliases =
            aliases.map(
                alias =>
                    String(alias).toLowerCase()
            )

        if (!aliases.includes(stem))
            aliases.unshift(stem)

        return {
            label:
                parsed.label || stem,

            aliases:
                aliases,

            colors:
                parsed.colors || {},

            path:
                filePath
        }
    }

    // ═════════════════════════════════════════════
    // Palette scanning
    // ═════════════════════════════════════════════

    function rescanPalettes() {
        scanProc.running = true
    }

    function setPaletteDir(path) {
        const trimmed =
            path.trim()

        if (!trimmed)
            return

        paletteDir =
            trimmed

        rescanPalettes()
    }

    property Process scanProc: Process {
        id: scanProc

        command: [
            "bash",
            "-c",
            "dir=\"" +
            manager.paletteDir.replace(
                /^~/,
                "$HOME"
            ) +
            "\"; " +

            "for f in \"$dir\"/*.json; do " +
            "[ -f \"$f\" ] || continue; " +

            "echo \"__QUICKSHELL_PALETTE__ $f\"; " +
            "cat \"$f\"; " +
            "echo; " +

            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const chunks =
                    this.text.split(
                        "__QUICKSHELL_PALETTE__ "
                    )

                const found = {}
                const aliases = {}

                for (const chunk of chunks) {
                    const trimmed =
                        chunk.trim()

                    if (!trimmed)
                        continue

                    const newline =
                        trimmed.indexOf("\n")

                    if (newline === -1)
                        continue

                    const filePath =
                        trimmed
                            .slice(
                                0,
                                newline
                            )
                            .trim()

                    const jsonText =
                        trimmed
                            .slice(
                                newline + 1
                            )

                    let parsed

                    try {
                        parsed =
                            JSON.parse(
                                jsonText
                            )
                    } catch (e) {
                        console.warn(
                            "ThemeManager: failed to parse",
                            filePath,
                            e
                        )
                        continue
                    }

                    const entry =
                        manager.parsePalette(
                            filePath,
                            parsed
                        )

                    const stem =
                        filePath
                            .split("/")
                            .pop()
                            .replace(
                                /\.json$/i,
                                ""
                            )
                            .toLowerCase()

                    found[stem] =
                        entry

                    for (
                        const alias
                        of entry.aliases
                    ) {
                        aliases[alias] =
                            stem
                    }
                }

                manager.palettes =
                    found

                manager.themeAliases =
                    aliases

                manager.paletteNames =
                    Object.keys(found).sort()

                if (
                    manager.paletteNames.length > 0 &&
                    !found[
                        manager.currentTheme
                    ]
                ) {
                    manager.currentTheme =
                        manager.paletteNames[0]
                }

                // Now that aliases are known,
                // restore the persisted theme.

                manager.loadCurrentTheme()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const err =
                    this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: scan failed ->",
                        err
                    )
            }
        }
    }

    Component.onCompleted:
        rescanPalettes()

    // ═════════════════════════════════════════════
    // Switcher visibility
    // ═════════════════════════════════════════════

    property bool switcherVisible: false

    function toggleSwitcher() {
        switcherVisible =
            !switcherVisible
    }

    function showSwitcher() {
        switcherVisible = true
    }

    function hideSwitcher() {
        switcherVisible = false
    }

    // ═════════════════════════════════════════════
    // External theming
    // ═════════════════════════════════════════════

    property Process applyExternalProc: Process {
        id: applyExternalProc

        stderr: StdioCollector {
            onStreamFinished: {
                const err =
                    this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: apply-theme failed ->",
                        err
                    )
            }
        }
    }

    function applyExternalTheme(themeKey) {
        console.log(
            "ThemeManager: applyExternalTheme called with",
            themeKey
        )

        const entry =
            palettes[themeKey]

        if (!entry || !entry.path)
            return

        const dir =
            paletteDir.replace(
                /^~/,
                "$HOME"
            )

        const scriptPath =
            dir + "/../apply-theme.py"

        const escapedEntryPath =
            entry.path.replace(
                /(["\\$`])/g,
                "\\$1"
            )

        applyExternalProc.command = [
            "bash",
            "-c",
            "python3 \"" +
            scriptPath +
            "\" \"" +
            escapedEntryPath +
            "\""
        ]

        applyExternalProc.running = true
    }

    // ═════════════════════════════════════════════
    // Palette file operations
    // ═════════════════════════════════════════════

    property Process savePaletteProc: Process {
        id: savePaletteProc

        onExited:
            manager.rescanPalettes()

        stderr: StdioCollector {
            onStreamFinished: {
                const err =
                    this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: savePalette failed ->",
                        err
                    )
            }
        }
    }

    function savePaletteFile(
        path,
        contents
    ) {
        savePaletteProc.command = [
            "bash",
            "-c",
            "printf '%s\\n' \"$2\" > \"$1\"",
            "bash",
            path,
            contents
        ]

        savePaletteProc.running = true
    }

    function savePalette(
        themeKey,
        contents
    ) {
        const entry =
            palettes[themeKey]

        if (!entry || !entry.path) {
            console.warn(
                "ThemeManager: no palette path for",
                themeKey
            )
            return false
        }

        savePaletteFile(
            entry.path,
            contents
        )

        return true
    }

    function saveNewPalette(
        rawName,
        contents
    ) {
        const label =
            String(rawName).trim()

        const slug =
            label
                .toLowerCase()
                .replace(
                    /[^a-z0-9]+/g,
                    "-"
                )
                .replace(
                    /^-+|-+$/g,
                    ""
                )

        if (!slug) {
            console.warn(
                "ThemeManager: invalid theme name"
            )
            return false
        }

        const dir =
            paletteDir.replace(
                /^~/,
                "$HOME"
            )

        saveNewProc.command = [
            "bash",
            "-c",
            "mkdir -p \"" +
            dir +
            "\" && printf '%s\\n' \"$1\" > \"" +
            dir +
            "/" +
            slug +
            ".json\"",
            "bash",
            contents
        ]

        saveNewProc.running = true

        return true
    }

    property Process saveNewProc: Process {
        id: saveNewProc

        onExited:
            manager.rescanPalettes()

        stderr: StdioCollector {
            onStreamFinished: {
                const err =
                    this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: saveNewPalette failed ->",
                        err
                    )
            }
        }
    }

    function editPalette(themeKey) {
        const entry =
            palettes[themeKey]

        if (!entry || !entry.path) {
            console.warn(
                "ThemeManager: no file path for",
                themeKey
            )
            return ""
        }

        return entry.path
    }

    // ═════════════════════════════════════════════
    // Delete palette
    // ═════════════════════════════════════════════

    property Process deleteProc: Process {
        id: deleteProc

        onExited:
            manager.rescanPalettes()

        stderr: StdioCollector {
            onStreamFinished: {
                const err =
                    this.text.trim()

                if (err.length > 0)
                    console.warn(
                        "ThemeManager: deletePalette failed ->",
                        err
                    )
            }
        }
    }

    function deletePalette(themeKey) {
        const entry =
            palettes[themeKey]

        if (!entry || !entry.path) {
            console.warn(
                "ThemeManager: no file path for",
                themeKey
            )
            return
        }

        deleteProc.command = [
            "rm",
            "-f",
            entry.path
        ]

        deleteProc.running = true

        if (
            currentTheme === themeKey
        ) {
            currentTheme =
                paletteNames.length > 1
                    ? paletteNames[
                        paletteNames.indexOf(
                            themeKey
                        ) === 0
                            ? 1
                            : 0
                    ]
                    : "mocha"

            saveCurrentTheme()
        }
    }

    // ═════════════════════════════════════════════
    // New palette template
    // ═════════════════════════════════════════════

    function defaultPaletteJson(label) {
        return JSON.stringify(
            {
                label:
                    label || "New Theme",

                aliases: [
                    label
                        ? label
                            .toLowerCase()
                            .replace(
                                /[^a-z0-9]+/g,
                                "-"
                            )
                        : "new-theme"
                ],

                colors: {
                    background:
                        "#1e1e2e",

                    backgroundSecondary:
                        "#181825",

                    backgroundDeep:
                        "#11111b",

                    surface:
                        "#313244",

                    surfaceSecondary:
                        "#45475a",

                    surfaceTertiary:
                        "#585b70",

                    overlay:
                        "#6c7086",

                    overlaySecondary:
                        "#7f849c",

                    overlayTertiary:
                        "#9399b2",

                    text:
                        "#cdd6f4",

                    textSecondary:
                        "#bac2de",

                    textMuted:
                        "#a6adc8",

                    accent:
                        "#b4befe",

                    accentSecondary:
                        "#cba6f7",

                    success:
                        "#a6e3a1",

                    warning:
                        "#f9e2af",

                    danger:
                        "#f38ba8",

                    info:
                        "#89b4fa"
                }
            },
            null,
            2
        )
    }
}
