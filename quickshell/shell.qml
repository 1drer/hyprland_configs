import Quickshell
import Quickshell.Io

import "./theme"

ShellRoot {
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
    WallpaperPicker {}
    Bar {}
    ThemeSwitcher {}
}
