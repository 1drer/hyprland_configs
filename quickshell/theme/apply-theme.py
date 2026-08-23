#!/usr/bin/env python3

import os
import sys

from python.palette import load_palette, resolve
from python.targets import apply_targets
from python.dunst import apply_dunst
from python.reload import reload_all, reload_kitty


def main():
    if len(sys.argv) < 2:
        print(
            "usage: apply-theme.py <palette.json>",
            file=sys.stderr,
        )
        sys.exit(1)

    palette_path = os.path.abspath(
        os.path.expanduser(sys.argv[1])
    )

    try:
        palette = load_palette(
            palette_path
        )

    except (OSError, ValueError) as e:
        print(
            f"error: {e}",
            file=sys.stderr,
        )
        sys.exit(1)

    colors = resolve(palette)

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    templates_dir = os.path.join(
        script_dir,
        "templates",
    )

    home = os.path.expanduser("~")

    # Normal template targets
    apply_targets(
        templates_dir,
        colors,
    )

    # Dunst
    apply_dunst(
        os.path.join(
            templates_dir,
            "dunst-block.tmpl",
        ),
        os.path.join(
            home,
            ".config/dunst/dunstrc",
        ),
        colors,
    )

    # Reload applications
    reload_all()

    # Kitty needs the generated theme path
    kitty_theme = os.path.join(
        home,
        ".config/kitty/current-theme.conf",
    )

    if os.path.isfile(kitty_theme):
        reload_kitty(
            kitty_theme
        )


if __name__ == "__main__":
    main()
