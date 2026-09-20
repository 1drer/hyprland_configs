//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick

import "./theme"
import "./services"

ShellRoot {

    // ═══════════════════════════════════════════════════════════════════
    // Main Bar
    // ═══════════════════════════════════════════════════════════════════

    Bar {
      id: bar
    }

    // ═══════════════════════════════════════════════════════════════════
    // Control Center
    // ═══════════════════════════════════════════════════════════════════

    Loader {
        active: ControlCenterState.visible

        sourceComponent: Component {
          ControlCenter {
            barHeight: bar.implicitHeight
            barTopMargin: bar.margins.top
          }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Power Menu
    // ═══════════════════════════════════════════════════════════════════

    Loader {
        active: PowerMenuState.visible

        sourceComponent: Component {
          PowerMenu {}
        }
    }

    // Action executor — long-lived, so it survives the menu window
    // being destroyed on close. The menu schedules a command through
    // PowerMenuState and we spawn it immediately; the child process
    // starts slowly enough that the menu surface is already gone by the
    // time hyprlock/systemctl takes over the screen.
    Process {
        id: powerActionProcess
    }

    Connections {
        target: PowerMenuState

        function onActionScheduled() {
            const command = PowerMenuState.pendingCommand

            if (command !== null) {
                powerActionProcess.command = command
                powerActionProcess.running = true
                PowerMenuState.pendingCommand = null
            }
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
    
    //NirtroControl 
    
  //  NitroControl{}

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

    // ═══════════════════════════════════════════════════════════════════
    // Power Menu IPC
    // ═══════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "power"

        function open(): void {
            PowerMenuState.open()
        }

        function toggle(): void {
            PowerMenuState.toggle()
        }

        function close(): void {
            PowerMenuState.close()
        }
    }
}