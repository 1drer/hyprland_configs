pragma Singleton

import QtQuick
import "./palettes" as Palettes

QtObject {
    id: manager


    // ═════════════════════════════════════════════
    // Theme selection
    // ═════════════════════════════════════════════

    property string currentTheme: "mocha"


    // ═════════════════════════════════════════════
    // Theme registry
    //
    // This is the ONLY place a new theme needs to be
    // registered. Everything else (active palette,
    // setTheme(), alias matching) derives from this.
    //
    // To add a theme:
    //   1. Create theme/palettes/YourTheme.qml
    //   2. Add it to theme/palettes/qmldir
    //   3. Add one entry below
    // ═════════════════════════════════════════════

    readonly property var themes: ({
        "mocha": {
            palette: Palettes.CatppuccinMocha,
            aliases: ["mocha", "catppuccin", "catppuccin-mocha"]
        },
        "gruvbox": {
            palette: Palettes.Gruvbox,
            aliases: ["gruvbox"]
          },
           "everforest": {
            palette: Palettes.Everforest,
            aliases: ["everforest"]
          },
          "rosepine": {
            palette: Palettes.Rosepine,
            aliases: ["rosepine"]
          }

    })

    readonly property var themeNames:
        Object.keys(themes)

    // ═════════════════════════════════════════════
    // Active palette
    // ═════════════════════════════════════════════

    readonly property QtObject palette:
        themes[currentTheme]
            ? themes[currentTheme].palette
            : themes["mocha"].palette


    // ═════════════════════════════════════════════
    // Semantic colors
    // ═════════════════════════════════════════════

    // Backgrounds

    readonly property color background:
        palette.base

    readonly property color backgroundSecondary:
        palette.mantle

    readonly property color backgroundDeep:
        palette.crust


    // Surfaces

    readonly property color surface:
        palette.surface0

    readonly property color surfaceSecondary:
        palette.surface1

    readonly property color surfaceTertiary:
        palette.surface2


    // Overlays

    readonly property color overlay:
        palette.overlay0

    readonly property color overlaySecondary:
        palette.overlay1

    readonly property color overlayTertiary:
        palette.overlay2


    // Text

    readonly property color text:
        palette.text

    readonly property color textSecondary:
        palette.subtext1

    readonly property color textMuted:
        palette.subtext0


    // Accents

    readonly property color accent:
        palette.lavender

    readonly property color accentSecondary:
        palette.mauve


    // Status

    readonly property color success:
        palette.green

    readonly property color warning:
        palette.yellow

    readonly property color danger:
        palette.red

    readonly property color info:
        palette.blue

    readonly property color peach:
        palette.peach

    readonly property color teal:
        palette.teal


    // ═════════════════════════════════════════════
    // Global Typography
    //
    // These are independent of the color palette.
    // ═════════════════════════════════════════════

    property string fontFamily:
        "JetBrainsMono Nerd Font"

    property int fontTiny:
        10

    property int fontSmall:
        11

    property int fontNormal:
        13

    property int fontLarge:
        15

    property int fontTitle:
        18

    property int fontRegular:
        400

    property int fontMedium:
        500

    property int fontBold:
        700

    property int fontHeavy:
        800


    // ═════════════════════════════════════════════
    // Theme switching
    // ═════════════════════════════════════════════

    function setTheme(name) {
        const normalized = name.toLowerCase()

        for (const key in themes) {
            if (themes[key].aliases.indexOf(normalized) !== -1) {
                currentTheme = key
                return
            }
        }

        console.warn(
            "ThemeManager: unknown theme:",
            name
        )
    }

    function nextTheme() {
        const names = themeNames
        const index = names.indexOf(currentTheme)
        setTheme(names[(index + 1) % names.length])
    }
}
