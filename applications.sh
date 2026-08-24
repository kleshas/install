#!/usr/bin/env bash

set -euo pipefail

# ==> Automatically Enable Multilib Repository if missing or commented out
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "==> Enabling multilib repository..."
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
        sudo sed -i '/^\[multilib\]/{n;s/^#//}' /etc/pacman.conf
    else
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    fi
fi

# Initialize package databases
sudo pacman -Sy

# --- APP CONFIGURATION LISTS ---
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
    gnucash
    grim
    grsync
    gthumb
    gvfs
    hplip
    htop
    hunspell-en_ca
    hyphen-en
    imagemagick
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
    libappindicator-gtk3
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
    qbittorrent
    reflector
    smartmontools
    steam
    stow
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

AUR_APPS=(
    amdsmi
    amdgpu_top
    bibata-cursor-theme-bin
    catppuccin-gtk-theme-frappe
    catppuccin-gtk-theme-macchiato
    catppuccin-gtk-theme-mocha
    catppuccin-qt5ct-git
    downgrade
    gammastep
    glfw-wayland
    heroic-games-launcher-bin
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
if ! command -v yay &> /dev/null; then
    echo "==> Preparing AUR helper..."
    YAY_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$YAY_DIR"
    cd "$YAY_DIR" || exit 1
    makepkg -si --noconfirm
    cd - >/dev/null || exit 1
    rm -rf "$YAY_DIR"
fi

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
    if [ -f "$HOME/.dotfiles/$profile_file" ]; then
        rm -f "$HOME/$profile_file"
        cp "$HOME/.dotfiles/$profile_file" "$HOME/"
    fi
done

# ==> Executing GNU Stow cleanly
echo "==> Executing GNU Stow..."
cd "$HOME/.dotfiles/stow"
stow --restow -t "$HOME" *

# Apply git standard identity metrics cleanly
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
echo "drivetemp" | sudo tee /etc/modules-load.d/drivetemp.conf > /dev/null

cat "$HOME/.dotfiles/crypttab" | sudo tee -a /etc/crypttab > /dev/null
cat "$HOME/.dotfiles/fstab" | sudo tee -a /etc/fstab > /dev/null

sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Attempt safe execution parameter shifts for target crypto block partitions
sudo cryptsetup --allow-discards --persistent refresh root || echo "Note: Root drive bypass optimized or non-LUKS."

echo "==> Installation completely finished! System ready for restart."
