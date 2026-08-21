// shell.qml
//
// Minimal Quickshell entry point that just loads the wallpaper picker.
//
// Place this file next to WallpaperPicker.qml in:
//   ~/.config/quickshell/shell.qml
//   ~/.config/quickshell/WallpaperPicker.qml
//
// Run with:      quickshell
// Toggle with:   qs ipc call wallpaper toggle

import Quickshell

ShellRoot {
  WallpaperPicker {}
  Bar {}
}
