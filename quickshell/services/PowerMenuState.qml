pragma Singleton
import QtQuick

// Visibility state for the power menu. Lives in a singleton so the
// shell's Loader (and the `qs ipc call power ...` IPC target) can
// control it from anywhere.
//
// Also relays scheduled actions from the (short-lived, Loader-owned)
// menu window to the shell's long-lived Timer/Process: the menu is
// destroyed on close, so it cannot own the process that must run the
// shutdown/lock command after it disappears.
QtObject {
    id: root

    property bool visible: false

    // Command (argv list) waiting to be spawned by the shell's executor.
    property var pendingCommand: null

    // Emitted when an action is requested. The shell listens and spawns
    // it after a short grace period.
    signal actionScheduled()

    function toggle() {
        visible = !visible
    }

    function close() {
        visible = false
    }

    function open() {
        visible = true
    }

    // Queue a command to run. Execution happens in the shell
    // (long-lived), not in the menu window (destroyed on close).
    function schedule(command) {
        root.pendingCommand = command
        root.actionScheduled()
    }
}

