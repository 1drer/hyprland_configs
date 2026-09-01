#!/usr/bin/env python3
"""
Generate a quickshell palette JSON (matching python/palette.py's ROLES
schema) from a wallpaper, using matugen's Material You color extraction.

Usage:
    matugen-wallpaper.py <image-path> [dark|light]

Writes: <this-script's-dir>/palettes/wallpaper.json

Requires matugen on PATH:
    cargo install matugen
    sudo pacman -S matugen        (Arch extra repo)
    yay -S matugen-bin            (AUR)
"""
import colorsys
import json
import os
import re
import subprocess
import sys

from python.palette import ROLES

HEX_RE = re.compile(r"^#?[0-9a-fA-F]{6}$")

# quickshell semantic role -> ordered list of matugen/Material roles to
# try. First one matugen actually returns wins.
ROLE_SOURCES = {
    "background": ["background"],
    "backgroundSecondary": ["surface_container_low", "surface_variant", "background"],
    "backgroundDeep": ["surface_container_lowest", "surface_dim", "background"],
    "surface": ["surface_container", "surface"],
    "surfaceSecondary": ["surface_container_high", "surface_variant"],
    "surfaceTertiary": ["surface_container_highest", "surface_variant"],
    "overlay": ["outline"],
    "overlaySecondary": ["outline_variant"],
    "overlayTertiary": ["surface_variant"],
    "text": ["on_background", "on_surface"],
    "textSecondary": ["on_surface_variant"],
    "textMuted": ["outline_variant", "on_surface_variant"],
    "accent": ["primary"],
    "accentSecondary": ["secondary", "tertiary"],
    "danger": ["error"],
}
# success / warning / info have no Material equivalent - derived from
# the accent color below via hue rotation, so they still feel tied to
# the wallpaper instead of being hardcoded.


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#" + "".join(
        f"{max(0, min(255, round(c * 255))):02x}" for c in rgb
    )


def semantic_color(hue_degrees, lightness=0.72, saturation=0.45):
    """A fixed, tuned pastel tone at the given hue - used for
    success/warning/info instead of inheriting the accent's raw HLS
    saturation, which can read as ~100% for light pastel colors and
    ends up looking neon rather than blending with the theme."""
    r, g, b = colorsys.hls_to_rgb((hue_degrees % 360) / 360.0, lightness, saturation)
    return rgb_to_hex((r, g, b))


SEMANTIC_HUES = {
    "success": 142,  # green
    "warning": 45,   # amber
    "info": 213,     # blue
}


def get_hue_degrees(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0


def tint(hex_color, hue_degrees, saturation, light_floor=None):
    """Recolor hex_color to the given hue/saturation while keeping its
    original lightness (or raising it to light_floor if it's below
    that) - adds a color cast without hurting contrast/readability."""
    r, g, b = hex_to_rgb(hex_color)
    _, l, _ = colorsys.rgb_to_hls(r, g, b)
    if light_floor is not None:
        l = max(l, light_floor)
    r2, g2, b2 = colorsys.hls_to_rgb((hue_degrees % 360) / 360.0, l, saturation)
    return rgb_to_hex((r2, g2, b2))


def get_lightness(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    _, l, _ = colorsys.rgb_to_hls(r, g, b)
    return l


# Material's tonal system keeps neutrals (background/surface/text)
# almost fully desaturated by design - that's what reads as "too
# black/gray" compared to a hand-tinted palette like Catppuccin,
# where every surface carries the accent's hue family. This pulls
# those neutral roles toward the accent's hue while preserving their
# original lightness, so contrast is unaffected - only the color cast
# changes.
# NOTE: dict order matters below - "background" must come before
# "backgroundDeep" (it does), because backgroundDeep's floor is
# computed relative to background's already-tinted value in the loop
# in build_colors().
NEUTRAL_TINT_TARGETS = {
    "background": 0.22,
    "backgroundSecondary": 0.24,
    "backgroundDeep": 0.26,
    "surface": 0.20,
    "surfaceSecondary": 0.18,
    "surfaceTertiary": 0.16,
    "overlay": 0.16,
    "overlaySecondary": 0.20,
    "overlayTertiary": 0.14,
    "text": 0.22,
    "textSecondary": 0.18,
    "textMuted": 0.16,
}
# Lightness safety net for roles that must stay legible/visible no
# matter what a given wallpaper produces. backgroundDeep is handled
# separately (relative to background) so it can never end up lighter
# than background - see build_colors().
NEUTRAL_LIGHT_FLOOR = {
    "textMuted": 0.50,
    "textSecondary": 0.55,
}


def _extract_hex(value):
    """Pull a hex string out of a value that might be a plain hex
    string, {"hex": "#.."}, {"color": "#.."}, or one of those nested
    under {"default": {...}} - matugen's exact JSON shape has changed
    across versions (v4.2.0 uses colors.<role>.default.color), so
    accept all of them rather than assuming one."""
    if isinstance(value, str) and HEX_RE.match(value):
        return value if value.startswith("#") else "#" + value
    if isinstance(value, dict):
        for key in ("hex", "color"):
            if key in value:
                return _extract_hex(value[key])
        if "default" in value:
            return _extract_hex(value["default"])
    return None


def find_role(data, role, mode):
    """Recursively search the parsed JSON for a key matching `role`
    (case-insensitive) and return its hex value. If multiple matches
    exist (e.g. under both a "light" and "dark" branch), prefer the
    one nested under a path segment matching `mode`."""
    candidates = []

    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                if k.lower() == role.lower():
                    hexval = _extract_hex(v)
                    if hexval:
                        candidates.append((path, hexval))
                walk(v, path + [k])

    walk(data, [])
    if not candidates:
        return None
    for path, hexval in candidates:
        if any(p.lower() == mode.lower() for p in path):
            return hexval
    return candidates[0][1]


def run_matugen(image_path, mode):
    try:
        result = subprocess.run(
            [
                "matugen",
                "image",
                image_path,
                "--json",
                "hex",
                "--mode",
                mode,
                # Some wallpapers have several similarly-dominant
                # colors; matugen then prompts interactively to pick
                # one, which hangs/fails when run headlessly (no
                # TTY). "--prefer saturation" both skips that prompt
                # and picks the most saturated dominant cluster
                # instead of the most frequent one - the most-
                # frequent pixel cluster is often a blended/antialiased
                # region with a stray tint that doesn't represent the
                # image (e.g. a lavender accent out of a gruvbox-toned
                # wallpaper), which Material's chroma boost then makes
                # worse. The most-saturated cluster is far more likely
                # to be an actual vivid color that's really in the image.
                "--prefer",
                "saturation",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        print(
            "error: matugen not found on PATH. Install it with "
            "'cargo install matugen', 'sudo pacman -S matugen', or "
            "'yay -S matugen-bin'.",
            file=sys.stderr,
        )
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"error: matugen failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(
            f"error: could not parse matugen output as JSON: {e}\n"
            f"raw output:\n{result.stdout}",
            file=sys.stderr,
        )
        sys.exit(1)


def build_colors(data, mode):
    colors = {}
    missing = []
    for role, sources in ROLE_SOURCES.items():
        hexval = None
        for source in sources:
            hexval = find_role(data, source, mode)
            if hexval:
                break
        if not hexval:
            missing.append(role)
            hexval = "#808080"
        colors[role] = hexval

    primary = colors.get("accent", "#808080")
    for role, hue in SEMANTIC_HUES.items():
        colors[role] = semantic_color(hue)

    # Give the neutral roles the accent's hue family instead of
    # Material's near-gray default.
    accent_hue = get_hue_degrees(primary)
    for role, sat in NEUTRAL_TINT_TARGETS.items():
        if role not in colors:
            continue
        if role == "backgroundDeep":
            # backgroundDeep was crushing to near-black regardless of
            # saturation (very low lightness reads as flat black no
            # matter the hue). Floor it, but relative to background's
            # already-tinted lightness (processed earlier in this
            # same loop) so it can never end up lighter than
            # background - just not much darker either.
            bg_l = get_lightness(colors.get("background", colors[role]))
            floor = min(0.09, max(0.0, bg_l - 0.015))
        else:
            floor = NEUTRAL_LIGHT_FLOOR.get(role)
        colors[role] = tint(colors[role], accent_hue, sat, light_floor=floor)

    if missing:
        print(
            "warning: could not find matugen colors for: "
            + ", ".join(missing)
            + " (filled with neutral gray - check matugen's JSON output "
              "shape with `matugen image <wallpaper> --json hex --mode "
              + mode + "` and adjust ROLE_SOURCES if needed)",
            file=sys.stderr,
        )

    for role in ROLES:
        colors.setdefault(role, "#808080")
    return colors


def main():
    if len(sys.argv) < 2:
        print("usage: matugen-wallpaper.py <image-path> [dark|light]", file=sys.stderr)
        sys.exit(1)
    image_path = os.path.abspath(os.path.expanduser(sys.argv[1]))
    mode = sys.argv[2] if len(sys.argv) > 2 else "dark"
    if not os.path.isfile(image_path):
        print(f"error: image not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    data = run_matugen(image_path, mode)
    colors = build_colors(data, mode)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(script_dir, "palettes", "wallpaper.json")
    palette = {
        "label": "Wallpaper (Auto)",
        "aliases": ["wallpaper", "auto"],
        "colors": colors,
    }
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(palette, f, indent=2)
        f.write("\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
