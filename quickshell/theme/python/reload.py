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
    run([
        "kitty",
        "@",
        "set-colors",
        "-a",
        theme_path,
    ])
