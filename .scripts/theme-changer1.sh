##!/bin/bash

#read -p "
#1. catppuccin-mocha
#2. catppuccin-frappe
#3. nord
#what theme?  " THEME
#echo "$THEME"
#if [[ "$THEME" == 1 ]]
 #then THEME="catppuccin-mocha"
#elif [[ "$THEME" == 2 ]]
 #then THEME="catppuccin-frappe"
#else THEME="nord"
#fi
#echo "$THEME"

#cp ~/.dotfiles/.scripts/wofi/${THEME}.css ~/.dotfiles/stow/wofi/.config/wofi/style.css
#cp ~/.dotfiles/.scripts/waybar/${THEME}.css ~/.dotfiles/stow/waybar/.config/waybar/material.css
#cp ~/.dotfiles/.scripts/conky/$THEME.conf ~/.dotfiles/stow/conky/.conkyrc
#cp ~/.dotfiles/.scripts/sway/${THEME} ~/.dotfiles/stow/sway/.config/sway/colors && swaymsg reload
#cp ~/.dotfiles/.scripts/qBittorrent/$THEME.qbtheme ~/.dotfiles/stow/qBittorrent/.config/qBittorrent/themes/custom.qbtheme

#cp ~/.dotfiles/.scripts/kitty/${THEME}.conf ~/.dotfiles/stow/kitty/.config/kitty/colors.conf


#cp ~/.dotfiles/.scripts/dunst/$THEME.conf ~/.dotfiles/stow/dunst/.config/dunst/dunstrc && dunstctl reload
#cp ~/.dotfiles/.scripts/geany/$THEME.conf ~/.dotfiles/stow/geany/.config/geany/colorschemes/custom.conf

#!/usr/bin/env bash

# Define paths
SCRIPTS_DIR="$HOME/.dotfiles/.scripts"
STOW_DIR="$HOME/.dotfiles/stow"

# 1. Interactive Selection Menu
PS3="Choose your desktop theme (enter number): "
options=("catppuccin-mocha" "catppuccin-frappe" "nord" "Quit")

select THEME in "${options[@]}"; do
    case "$THEME" in
        "catppuccin-mocha"|"catppuccin-frappe"|"nord")
            echo "Applying theme: $THEME"
            break
            ;;
        "Quit")
            echo "Exiting."
            exit 0
            ;;
        *) 
            echo "Invalid selection. Please choose a valid number."
            ;;
    esac
done

# 2. Parallel File Mapping Array (Source File -> Target Destination)
# This removes repetitive code blocks and makes adding apps easy later.
declare -A file_maps=(
    ["$SCRIPTS_DIR/wofi/${THEME}.css"]="$STOW_DIR/wofi/.config/wofi/style.css"
    ["$SCRIPTS_DIR/waybar/${THEME}.css"]="$STOW_DIR/waybar/.config/waybar/material.css"
    ["$SCRIPTS_DIR/conky/${THEME}.conf"]="$STOW_DIR/conky/.conkyrc"
    ["$SCRIPTS_DIR/sway/${THEME}"]="$STOW_DIR/sway/.config/sway/colors"
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
        # Create parent directories dynamically if they do not exist
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    else
        echo "Warning: Source configuration file not found: $src"
    fi
done

# 5. Hot Reload Active Desktop Components Safely
echo "Reloading runtime desktop services..."

# Reload Sway WM
if command -v swaymsg &> /dev/null && pgrep -x sway &> /dev/null; then
    swaymsg reload
fi

# Reload Dunst Notification Daemon
if command -v dunstctl &> /dev/null && pgrep -x dunst &> /dev/null; then
    dunstctl reload
fi

# Reload Waybar
if pgrep -x waybar &> /dev/null; then
    pkill -SIGUSR2 waybar
fi

# Reload Kitty Terminal instances 
if pgrep -x kitty &> /dev/null; then
    pkill -USR1 kitty
fi

echo "Theme update successfully completed!"
