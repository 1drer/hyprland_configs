#!/usr/bin/env bash

set -u

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
ROFI_CONFIG_DIR="${ROFI_CONFIG_DIR:-$HOME/.config/rofi}"
THEME="${ROFI_WALLPAPER_THEME:-$ROFI_CONFIG_DIR/wallpaper-picker.rasi}"

die() {
    printf 'wallpaper-picker: %s\n' "$1" >&2
    exit 1
}

command -v rofi >/dev/null 2>&1 || die "rofi is not installed"
command -v awww >/dev/null 2>&1 || die "awww is not installed"

[[ -d "$WALLPAPER_DIR" ]] || die "wallpaper directory does not exist: $WALLPAPER_DIR"
[[ -f "$THEME" ]] || die "rofi theme does not exist: $THEME"

find_wallpapers() {
    find "$WALLPAPER_DIR" -type f \
        \( \
            -iname '*.jpg' \
            -o -iname '*.jpeg' \
            -o -iname '*.png' \
            -o -iname '*.webp' \
            -o -iname '*.bmp' \
            -o -iname '*.gif' \
        \) \
        -printf '%T@ %p\n' |
        sort -nr |
        cut -d' ' -f2-
}

current_wallpaper() {
    awww query 2>/dev/null |
        sed -n 's/.*currently displaying: image: //p' |
        head -n 1
}

apply_wallpaper() {
    local wallpaper="$1"

    [[ -f "$wallpaper" ]] || return 1

    awww img "$wallpaper" \
        --transition-type random \
        --transition-fps 60 \
        --transition-duration 1

    # Notify Quickshell ThemeManager if IPC is available.
    if command -v qs >/dev/null 2>&1; then
        qs ipc call ThemeManager onWallpaperChanged "$wallpaper" \
            >/dev/null 2>&1 || true
    fi

    # Optional external theme bridge.
    local bridge="$HOME/.config/quickshell/theme/rofi-wallpaper-theme.sh"

    if [[ -x "$bridge" ]]; then
        "$bridge" "$wallpaper" >/dev/null 2>&1 || true
    fi
}

mapfile -t wallpapers < <(find_wallpapers)

((${#wallpapers[@]} > 0)) ||
    die "no wallpapers found in $WALLPAPER_DIR"

current="$(current_wallpaper || true)"

entries=""

for i in "${!wallpapers[@]}"; do
    path="${wallpapers[$i]}"
    name="$(basename "$path")"

    active="false"

    if [[ -n "$current" && "$path" == "$current" ]]; then
        active="true"
    fi

    entries+="${name}"$'\0'
    entries+="icon"$'\x1f'"${path}"$'\x1f'
    entries+="active"$'\x1f'"${active}"$'\n'
done

selection="$(
    printf '%s' "$entries" |
        rofi \
            -dmenu \
            -i \
            -show-icons \
            -theme "$THEME" \
            -p "Wallpaper" \
            -mesg "Enter apply  •  Esc cancel"
)"

[[ -n "$selection" ]] || exit 0

selected_path=""

for path in "${wallpapers[@]}"; do
    if [[ "$(basename "$path")" == "$selection" ]]; then
        selected_path="$path"
        break
    fi
done

[[ -n "$selected_path" ]] ||
    die "could not resolve selected wallpaper"

apply_wallpaper "$selected_path"
