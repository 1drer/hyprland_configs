import os

from .renderer import render
from .writer import write


TARGETS = [
    {
        "name": "Kitty",
        "template": "kitty.conf.tmpl",
        "output": "~/.config/kitty/current-theme.conf",
    },
    {
        "name": "GTK 3",
        "template": "gtk3.css.tmpl",
        "output": "~/.config/gtk-3.0/gtk.css",
    },
    {
        "name": "GTK 4",
        "template": "gtk4.css.tmpl",
        "output": "~/.config/gtk-4.0/gtk.css",
    },
    {
        "name": "Rofi",
        "template": "rofi-colors.rasi.tmpl",
        "output": "~/.config/rofi/colors.rasi",
    },
    {
        "name": "btop",
        "template": "btop.theme.tmpl",
        "output": "~/.config/btop/themes/quickshell.theme",
    },
    {
        "name": "Hyprland",
        "template": "hyprland-colors.lua.tmpl",
        "output": "~/.config/hypr/colors.lua",
    },
    {
        "name": "hyprlock",
        "template": "hyprlock-colors.conf.tmpl",
        "output": "~/.config/hypr/colors-hyprlock.conf",
    },
    {
        "name": "hyprtoolkit",
        "template": "hyprtoolkit-colors.conf.tmpl",
        "output": "~/.config/hypr/colors-hyprtoolkit.conf",
    },
    {
    "name": "Neovim",
    "template": "nvim-theme.lua.tmpl",
    "output": "~/.config/nvim/colors/quickshell.lua",
    },
]


def apply_targets(templates_dir, colors):
    home = os.path.expanduser("~")

    for target in TARGETS:
        template_path = os.path.join(
            templates_dir,
            target["template"],
        )

        if not os.path.isfile(template_path):
            continue

        output_path = os.path.expanduser(
            target["output"]
        )

        rendered = render(
            template_path,
            colors,
        )

        write(
            rendered,
            output_path,
        )
