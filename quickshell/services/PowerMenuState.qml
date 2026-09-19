pragma Singleton
import QtQuick

// Visibility state for the power menu. Lives in a singleton so the
// shell's Loader (and the `qs ipc call power ...` IPC target) can
// control it from anywhere.
QtObject {
    id: root

    property bool visible: false

    function toggle() {
        visible = !visible
    }

    function close() {
        visible = false
    }

    function open() {
        visible = true
    }
}