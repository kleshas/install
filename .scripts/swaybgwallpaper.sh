#!/usr/bin/env bash
WALL_DIR="/mnt/SN850/STANDALONES/Pictures/wallpapers"
TARGET="$HOME/.local/share/current_bg.png"

# Pick a random image and copy it
RAND_IMG=$(find "$WALL_DIR" -type f | shuf -n 1)
cp "$RAND_IMG" "$TARGET"
magick $HOME/.local/share/current_bg.png $HOME/.local/share/current_bg.jpg

# Apply via swaymsg if swaybg is running, or launch swaybg
if pgrep -x swaybg > /dev/null; then
    swaymsg output "*" bg "$TARGET" fill
else
    swaybg -o "*" -i "$TARGET" -m fill &
fi
