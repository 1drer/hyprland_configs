import Quickshell
import Quickshell.Io
import QtQuick

import "./theme"
import "./services"

ShellRoot {

    // ═══════════════════════════════════════════════════════════════════
    // Main Bar
    // ═══════════════════════════════════════════════════════════════════

    Bar {}

    // ═══════════════════════════════════════════════════════════════════
    // Control Center
    // ═══════════════════════════════════════════════════════════════════

    Loader {
        active: ControlCenterState.visible

        sourceComponent: Component {
            ControlCenter {}
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Wallpaper Picker
    // ═══════════════════════════════════════════════════════════════════

    LazyLoader {
        id: wallpaperPickerLoader

        active: false

        WallpaperPicker {
            onPickerClosed: {
                wallpaperPickerLoader.active = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Theme Switcher
    // ═══════════════════════════════════════════════════════════════════

    LazyLoader {
        id: themeSwitcherLoader

        active: ThemeManager.switcherVisible

        ThemeSwitcher {}
    }

    // ═══════════════════════════════════════════════════════════════════
    // Wallpaper IPC
    // ═══════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            wallpaperPickerLoader.active = true
        }

        function toggle(): void {
            wallpaperPickerLoader.active =
                !wallpaperPickerLoader.active
        }

        function close(): void {
            wallpaperPickerLoader.active = false
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Theme IPC
    // ═══════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "theme"

        function set(name: string): void {
            ThemeManager.setTheme(name)
        }

        function toggle(): void {
            ThemeManager.toggleSwitcher()
        }

        function next(): void {
            ThemeManager.nextTheme()
        }
    }
}
