import subprocess
import sys


def run(command):
    try:
        subprocess.run(
            command,
            check=False,
        )

    except FileNotFoundError:
        print(
            f"warning: command not found: {command[0]}",
            file=sys.stderr,
        )


def reload_all():
    run([
        "hyprctl",
        "reload",
    ])
    run ([
        "pkill",
        "-SIGUSR2",
        "hyprlock"
    ])

    run([
        "dunstctl",
        "reload",
    ])

    run([
        "pkill",
        "-SIGUSR2",
        "btop",
    ])


def reload_kitty(theme_path):
    try:
        subprocess.run(
            [
                "kitty",
                "@",
                "set-colors",
                "-a",
                theme_path,
            ],
            check=False,
            timeout=1,
        )
    except subprocess.TimeoutExpired:
        print(
            "warning: kitty @ set-colors timed out "
            "(stale/unreachable remote-control socket?)",
            file=sys.stderr,
        )
    except FileNotFoundError:
        print(
            "warning: command not found: kitty",
            file=sys.stderr,
        )
