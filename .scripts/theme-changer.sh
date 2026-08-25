#!/usr/bin/env bash
set -euo pipefail

# Define paths
SCRIPTS_DIR="$HOME/.dotfiles/.scripts"
STOW_DIR="$HOME/.dotfiles/stow"

# 1. Interactive Selection Menu
PS3="Choose your desktop theme (enter number): "
options=("catppuccin-mocha" "catppuccin-macchiato" "catppuccin-frappe" "nord" "everforest" "dracula" "gruvbox-dark" "Quit")

select THEME in "${options[@]}"; do
    if [[ "$THEME" == "Quit" ]]; then
        echo "Exiting."
        exit 0
    elif [[ -n "$THEME" ]]; then
        echo "Applying theme: $THEME"
        break
    else
        echo "Invalid selection. Please choose a valid number."
    fi
done

# 2. Parallel File Mapping Array
declare -A file_maps=(
    ["$SCRIPTS_DIR/wofi/${THEME}.css"]="$STOW_DIR/wofi/.config/wofi/style.css"
    ["$SCRIPTS_DIR/waybar/${THEME}.css"]="$STOW_DIR/waybar/.config/waybar/material.css"
    ["$SCRIPTS_DIR/conky/${THEME}.conf"]="$STOW_DIR/conky/.conkyrc"
    ["$SCRIPTS_DIR/sway/${THEME}.css"]="$STOW_DIR/sway/.config/sway/colors.css"
    ["$SCRIPTS_DIR/qBittorrent/${THEME}.qbtheme"]="$STOW_DIR/qBittorrent/.config/qBittorrent/themes/custom.qbtheme"
    ["$SCRIPTS_DIR/kitty/${THEME}.conf"]="$STOW_DIR/kitty/.config/kitty/colors.conf"
    ["$SCRIPTS_DIR/dunst/${THEME}.conf"]="$STOW_DIR/dunst/.config/dunst/dunstrc"
    ["$SCRIPTS_DIR/geany/${THEME}.conf"]="$STOW_DIR/geany/.config/geany/colorschemes/custom.conf"
)

# 3. Copy with Safety Checks
echo "Copying config template assets..."
for src in "${!file_maps[@]}"; do
    dest="${file_maps[$src]}"
         
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    else
        echo "Warning: Source configuration file not found: $src"
    fi
done

# 4. Run Theme Script Safely
gtk_script="$SCRIPTS_DIR/gtk-3.0/${THEME}.sh"
if [[ -f "$gtk_script" ]]; then
    echo "Running GTK theme script..."
    bash "$gtk_script"
else
    echo "Warning: GTK script not found: $gtk_script"
fi

# 5. Hot Reload Active Desktop Components Safely
echo "Reloading runtime desktop services..."

if command -v swaymsg &> /dev/null && pgrep -x sway &> /dev/null; then
    swaymsg reload
fi

if command -v dunstctl &> /dev/null && pgrep -x dunst &> /dev/null; then
    dunstctl reload
fi

if pgrep -x waybar &> /dev/null; then
    pkill -SIGUSR2 waybar
fi

if pgrep -x kitty &> /dev/null; then
    pkill -USR1 kitty
fi

echo "Theme update successfully completed!"
read -rp "Press [Enter] key to continue..."
