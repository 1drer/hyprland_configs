import json
import os


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


def load_palette(path):
    path = os.path.abspath(
        os.path.expanduser(path)
    )

    if not os.path.isfile(path):
        raise FileNotFoundError(
            f"palette not found: {path}"
        )

    try:
        with open(
            path,
            "r",
            encoding="utf-8",
        ) as f:
            return json.load(f)

    except json.JSONDecodeError as e:
        raise ValueError(
            f"invalid palette JSON: {e}"
        ) from e


def resolve(entry):
    colors = entry.get("colors", {})

    return {
        role: colors.get(
            role,
            "#808080",
        )
        for role in ROLES
    }
