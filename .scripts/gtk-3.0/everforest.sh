#!/bin/bash

# Define your preferred theme variations
THEME_NAME="Everforest-Dark"

# Apply settings directly to the GSettings backend
gsettings set org.gnome.desktop.interface gtk-theme "Everforest-Dark"
gsettings set org.gnome.desktop.interface font-name "Liberation Mono 11"

# Optional: Force nwg-look to refresh its configuration files if it is running
if command -v nwg-look &> /dev/null; then
    nwg-look -x  # Reads current gsettings and exports them to configuration files
fi
