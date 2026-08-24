#!/usr/bin/env bash

set -euo pipefail
# ==> Automatically Enable Multilib Repository if missing
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "==> Enabling multilib repository..."
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
fi

# Initialize package databases
sudo pacman -Sy

# --- APP CONFIGURATION LISTS ---
# Official repository packages (Vertical layout for clean comments)
PACMAN_APPS=(
    alsa-utils
    android-file-transfer
    btrfs-progs
    calibre
    conky
    cups
    dunst
    feh
    file-roller
    firefox
    geany
    geany-plugins
    grim
    grsync
    gthumb
    gvfs
    hddtemp
    hplip
    htop
    hunspell-en_ca
    hyphen-en
    jdk-openjdk
    jdk8-openjdk
    keepassxc
    kitty
    lib32-gnutls
    lib32-gtk3
    lib32-libva
    lib32-libva-mesa-driver
    lib32-libxcomposite
    lib32-libxinerama
    lib32-libxslt
    lib32-mesa
    lib32-mpg123
    lib32-opencl-icd-loader
    lib32-pipewire
    lib32-vulkan-icd-loader
    lib32-vulkan-intel
    lib32-vulkan-radeon
    libappindicator-gtk3        # Required for gammastep-indicator tray rendering
    libreoffice-fresh
    libva-mesa-driver
    linux-headers
    lutris
    man-db
    mesa
    mpg123
    mpv
    ncdu
    noto-fonts-emoji
    nvme-cli
    obsidian
    opencl-icd-loader
    otf-montserrat
    pacman-contrib
    pavucontrol
    pbzip2
    pigz
    pipewire
    pipewire-alsa
    pipewire-pulse
    polkit-gnome
    qbittorrent
    reflector
    smartmontools
    steam
    sysstat
    thunar
    thunar-archive-plugin
    thunderbird
    ttf-dejavu
    ttf-droid
    ttf-liberation
    unrar
    virtualbox
    vulkan-icd-loader
    vulkan-intel
    vulkan-radeon
    wget
    wine-staging
    xf86-video-amdgpu
    zathura
)

# AUR repository packages (Vertical layout for clean comments)
AUR_APPS=(
    Amdsmi
    amdgpu_top
    bibata-cursor-theme-bin
    catppuccin-gtk-theme-frappe
    catppuccin-gtk-theme-macchiato
    catppuccin-gtk-theme-mocha
    catppuccin-qt5ct-git
    downgrade
    gammastep
    glfw-wayland
    gnucash
    heroic-games-launcher-bin
    imagemagick
    mcomix
    nwg-look
    otf-font-awesome
    prelockd
    prismlauncher
    protontricks
    qt5-wayland
    qt5ct
    qt6-wayland
    slurp
    stow
    swaybg
    swaylock-effects
    swaytools
    tartube
    ttf-jetbrains-mono-nerd
    waybar
    wl-clipboard
    wofi
    xdg-desktop-portal-gtk
    xnconvert
    xorg-xlsclients
    xorg-xwayland
    ydotool
)

# ==> Install yay safely inside an isolated temporary sandbox
echo "==> Preparing AUR helper..."
# 1. Create a secure temporary directory
YAY_DIR=$(mktemp -d)
# 2. Clone from the correct AUR repository endpoint
git clone https://aur.archlinux.org/yay-bin.git "$YAY_DIR"
# 3. Enter directory, build/install without prompts, and return safely
cd "$YAY_DIR" || exit 1
makepkg -si --noconfirm
cd - >/dev/null || exit 1
# 4. Clean up temporary files
rm -rf "$YAY_DIR"

# ==> Install core native system distributions
echo "==> Synchronizing system infrastructure software..."
sudo pacman -S --needed --noconfirm "${PACMAN_APPS[@]}"

# ==> Run AUR software provisioning profile routines
echo "==> Refreshing composite user repositories..."
yay -S --needed --noconfirm \
    --answerclean All \
    --answerdiff None \
    --answerupgrade None \
    "${AUR_APPS[@]}"
yay --save --answerclean None --answerdiff None

# ==> Clone and configure profile runtime assets
echo "==> Resolving dotfiles tracking tree..."
rm -rf ~/.dotfiles
git clone https://github.com/kleshas/dotfiles ~/.dotfiles

# Deploy standard localized environment strings profiles safely
for profile_file in .profile .bashrc .bash_profile .Xresources .Xdefaults; do
    if [ -f ~/.dotfiles/$profile_file ]; then
        rm -f ~/$profile_file
        cp ~/.dotfiles/$profile_file ~/
    fi
done

# ==> Resolve file and folder path conflicts before running GNU Stow
echo "==> Clearing target file conflicts for GNU Stow..."
cd ~/.dotfiles/stow

for pkg in */; do
    pkg="${pkg%/}"
    find "$pkg" -mindepth 1 | while read -r source_path; do
        relative_target="${source_path#"$pkg"/}"
        full_target=~/$relative_target
        
        if [ -d "$source_path" ] && [ -f "$full_target" ] && [ ! -L "$full_target" ]; then
            echo "Removing conflicting file: $full_target"
            rm -f "$full_target"
        elif [ -d "$source_path" ]; then
            mkdir -p "$full_target"
        elif [ -f "$source_path" ] && [ -e "$full_target" ] && [ ! -L "$full_target" ]; then
            echo "Removing conflicting file: $full_target"
            rm -f "$full_target"
        fi
    done
done

# Map symlinks over file structures via GNU Stow using relative target step backs
echo "==> Executing GNU Stow..."
stow -d ~/.dotfiles/stow" -t ~/ */

# Apply git standard identity metrics cleanly via targeted execution sub-shells
git config --global user.email "kleshas@mailbox.org"
git config --global user.name "kleshas"

# ==> Run Final Housekeeping Adjustments
echo "==> Sweeping localized system resource pools..."
sudo pacman -Sc --noconfirm

# Configure operational parameters rulesets
sudo mkdir -p /etc/xdg/reflector
echo "--protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" | sudo tee /etc/xdg/reflector/reflector.conf

# Synchronize essential startup processes status maps
sudo systemctl enable reflector.service cups.service fstrim.timer prelockd.service

# Apply runtime system layout tweaks safely
echo "drivetemp" | sudo tee /etc/modules-load.d/modules.conf

sudo cp ~/.dotfiles/crypttab /etc/crypttab
sudo bash -c "cat ~/.dotfiles/fstab >> /etc/fstab"
fi

sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Attempt safe execution parameter shifts for target crypto block partitions
sudo cryptsetup --allow-discards --persistent refresh root || echo "Note: Root drive bypass optimized or non-LUKS."

echo "==> Installation completely finished! System ready for restart."
