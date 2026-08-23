#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys


# ═════════════════════════════════════════════════════════════════════════════
# Semantic roles
# ═════════════════════════════════════════════════════════════════════════════

ROLES = [
    "background",
    "backgroundSecondary",
    "backgroundDeep",

    "surface",
    "surfaceSecondary",
    "surfaceTertiary",

    "overlay",
    "overlaySecondary",
    "overlayTertiary",

    "text",
    "textSecondary",
    "textMuted",

    "accent",
    "accentSecondary",

    "success",
    "warning",
    "danger",
    "info",
]


# ═════════════════════════════════════════════════════════════════════════════
# Palette
# ═════════════════════════════════════════════════════════════════════════════

def color_for(entry, role):
    colors = entry.get("colors", {})
    semantic = entry.get("semantic", {})

    key = (
        semantic.get(role)
        if semantic.get(role)
        else role
    )

    return colors.get(key, "#808080")


def resolve(entry):
    return {
        role: color_for(entry, role)
        for role in ROLES
    }


# ═════════════════════════════════════════════════════════════════════════════
# Template rendering
# ═════════════════════════════════════════════════════════════════════════════

def render(template_path, resolved):
    with open(
        template_path,
        "r",
        encoding="utf-8",
    ) as f:
        text = f.read()

    def repl(match):
        key = match.group(1)

        if key.endswith("_rgb"):
            base = key[:-4]

            return resolved.get(
                base,
                "#808080",
            ).lstrip("#")

        return resolved.get(
            key,
            "#808080",
        )

    return re.sub(
        r"\{\{(\w+)\}\}",
        repl,
        text,
    )


# ═════════════════════════════════════════════════════════════════════════════
# File writing
# ═════════════════════════════════════════════════════════════════════════════

def write(text, out_path):
    directory = os.path.dirname(out_path)

    if directory:
        os.makedirs(
            directory,
            exist_ok=True,
        )

    with open(
        out_path,
        "w",
        encoding="utf-8",
    ) as f:
        f.write(text)


# ═════════════════════════════════════════════════════════════════════════════
# Dunst theme block injection
# ═════════════════════════════════════════════════════════════════════════════

def inject_theme_blocks(
    rendered_template,
    target_path,
):
    if not os.path.isfile(target_path):
        print(
            f"warning: {target_path} not found, skipping",
            file=sys.stderr,
        )
        return

    with open(
        target_path,
        "r",
        encoding="utf-8",
    ) as f:
        content = f.read()

    # Find every complete block in the generated template.
    template_pattern = re.compile(
        r"# (THEME_[A-Z0-9_]+_BEGIN)"
        r".*?"
        r"# (THEME_[A-Z0-9_]+_END)",
        re.DOTALL,
    )

    rendered_blocks = {}

    for match in template_pattern.finditer(
        rendered_template
    ):
        begin = match.group(1)
        end = match.group(2)

        # Make sure BEGIN/END names correspond.
        expected_end = begin.replace(
            "_BEGIN",
            "_END",
        )

        if end != expected_end:
            print(
                f"warning: mismatched Dunst markers: "
                f"{begin} / {end}",
                file=sys.stderr,
            )
            continue

        rendered_blocks[begin] = match.group(0)

    # Find blocks in the real dunstrc.
    target_pattern = re.compile(
        r"# (THEME_[A-Z0-9_]+_BEGIN)"
        r".*?"
        r"# (THEME_[A-Z0-9_]+_END)",
        re.DOTALL,
    )

    replaced = set()

    def replace(match):
        begin = match.group(1)
        end = match.group(2)

        expected_end = begin.replace(
            "_BEGIN",
            "_END",
        )

        if end != expected_end:
            return match.group(0)

        replacement = rendered_blocks.get(begin)

        if replacement is None:
            return match.group(0)

        replaced.add(begin)

        return replacement

    content = target_pattern.sub(
        replace,
        content,
    )

    # Warn about template blocks that don't exist
    # in the target configuration.
    for begin in rendered_blocks:
        if begin not in replaced:
            print(
                f"warning: Dunst block not found in dunstrc: "
                f"{begin}",
                file=sys.stderr,
            )

    with open(
        target_path,
        "w",
        encoding="utf-8",
    ) as f:
        f.write(content)


# ═════════════════════════════════════════════════════════════════════════════
# External command helper
# ═════════════════════════════════════════════════════════════════════════════

def run_if_available(command):
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


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():

    # ── Arguments ────────────────────────────────────────────────────────────

    if len(sys.argv) < 2:
        print(
            "usage: apply-theme.py <palette.json>",
            file=sys.stderr,
        )
        sys.exit(1)

    palette_path = os.path.abspath(
        os.path.expanduser(sys.argv[1])
    )

    if not os.path.isfile(palette_path):
        print(
            f"error: palette not found: {palette_path}",
            file=sys.stderr,
        )
        sys.exit(1)

    # ── Load palette ─────────────────────────────────────────────────────────

    try:
        with open(
            palette_path,
            "r",
            encoding="utf-8",
        ) as f:
            entry = json.load(f)

    except (OSError, json.JSONDecodeError) as e:
        print(
            f"error: failed to load palette: {e}",
            file=sys.stderr,
        )
        sys.exit(1)

    resolved = resolve(entry)

    # ── Paths ─────────────────────────────────────────────────────────────────

    home = os.path.expanduser("~")

    script_dir = os.path.dirname(
        os.path.abspath(__file__)
    )

    templates_dir = os.path.join(
        script_dir,
        "templates",
    )

    def tmpl(name):
        return os.path.join(
            templates_dir,
            name,
        )

    # ═════════════════════════════════════════════════════════════════════════
    # Kitty
    # ═════════════════════════════════════════════════════════════════════════

    kitty_template = tmpl(
        "kitty.conf.tmpl"
    )

    if os.path.isfile(kitty_template):
        write(
            render(
                kitty_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/kitty/current-theme.conf",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # GTK
    # ═════════════════════════════════════════════════════════════════════════

    gtk_template = tmpl(
        "gtk.css.tmpl"
    )

    if os.path.isfile(gtk_template):
        gtk_css = render(
            gtk_template,
            resolved,
        )

        write(
            gtk_css,
            os.path.join(
                home,
                ".config/gtk-3.0/gtk.css",
            ),
        )

        write(
            gtk_css,
            os.path.join(
                home,
                ".config/gtk-4.0/gtk.css",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # Rofi
    # ═════════════════════════════════════════════════════════════════════════

    rofi_template = tmpl(
        "rofi-colors.rasi.tmpl"
    )

    if os.path.isfile(rofi_template):
        write(
            render(
                rofi_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/rofi/colors.rasi",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # btop
    # ═════════════════════════════════════════════════════════════════════════

    btop_template = tmpl(
        "btop.theme.tmpl"
    )

    if os.path.isfile(btop_template):
        write(
            render(
                btop_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/btop/themes/quickshell.theme",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # Dunst
    # ═════════════════════════════════════════════════════════════════════════

    dunst_template = tmpl(
        "dunst-block.tmpl"
    )

    dunst_config = os.path.join(
        home,
        ".config/dunst/dunstrc",
    )

    if os.path.isfile(dunst_template):
        dunst_block = render(
            dunst_template,
            resolved,
        )

        inject_theme_blocks(
            dunst_block,
            dunst_config,
        )

    # ═════════════════════════════════════════════════════════════════════════
    # Hyprland
    # ═════════════════════════════════════════════════════════════════════════

    hyprland_template = tmpl(
        "hyprland-colors.lua.tmpl"
    )

    if os.path.isfile(hyprland_template):
        write(
            render(
                hyprland_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/hypr/colors.lua",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # hyprlock
    # ═════════════════════════════════════════════════════════════════════════

    hyprlock_template = tmpl(
        "hyprlock-colors.conf.tmpl"
    )

    if os.path.isfile(hyprlock_template):
        write(
            render(
                hyprlock_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/hypr/colors-hyprlock.conf",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # hyprtoolkit
    # ═════════════════════════════════════════════════════════════════════════

    hyprtoolkit_template = tmpl(
        "hyprtoolkit-colors.conf.tmpl"
    )

    if os.path.isfile(hyprtoolkit_template):
        write(
            render(
                hyprtoolkit_template,
                resolved,
            ),
            os.path.join(
                home,
                ".config/hypr/colors-hyprtoolkit.conf",
            ),
        )

    # ═════════════════════════════════════════════════════════════════════════
    # Reload
    # ═════════════════════════════════════════════════════════════════════════

    # Hyprland
    run_if_available([
        "hyprctl",
        "reload",
    ])

    # Kitty
    kitty_theme = os.path.join(
        home,
        ".config/kitty/current-theme.conf",
    )

    if os.path.isfile(kitty_theme):
        run_if_available([
            "kitty",
            "@",
            "set-colors",
            "-a",
            kitty_theme,
        ])

    # Dunst
    run_if_available([
        "dunstctl",
        "reload",
    ])
    # btop
    run_if_available([
        "pkill",
        "-SIGUSR2",
        "btop"
    ])


# ═════════════════════════════════════════════════════════════════════════════
# Entry point
# ═════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    main()
