#!/usr/bin/env bash

set -euo pipefail

# Check for required arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <hostname> <username>"
    exit 1
fi

HOSTNAME="$1"
USERNAME="$2"
USER_HOME="/home/$USERNAME"

# Ensure script is not run directly as root, but can elevate via sudo
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
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
    lib32-libpulse
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
    libappindicator-gtk3 #for gammastep-indicator
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
    xarchiver
    xf86-video-amdgpu
    zathura
)

AUR_APPS=(
    Amdsmi
    amdgpu_top
    bibata-cursor-theme-bin
    catppuccin-gtk-theme-frappe
    catppuccin-gtk-theme-macchiato
    catppuccin-gtk-theme-mocha
    catppuccin-qt5ct-git
    downgrade
    evtest
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

# ==> Install yay (AUR Helper) safely in a temporary location
echo "==> Installing yay (AUR Helper)..."
YAY_DIR=$(mktemp -d)
git clone https://aur.archlinux.org/yay-bin.git "$YAY_DIR"
cd "$YAY_DIR"
makepkg -si --noconfirm
cd -
rm -rf "$YAY_DIR"

# ==> Install official packages
echo "==> Installing Pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_APPS[@]}"

# ==> Install AUR packages with completely silent automation configs
echo "==> Installing AUR packages..."
yay -S --needed --noconfirm \
    --answerclean All \
    --answerdiff None \
    --answerupgrade None \
    "${AUR_APPS[@]}"
yay --save --answerclean None --answerdiff None

# ==> Clone and configure the dotfiles using the execution user's directory variable
echo "==> Cloning dotfiles repo..."
rm -rf "$USER_HOME/.dotfiles"
git clone https://github.com/kleshas/dotfiles "$USER_HOME/.dotfiles"

# Change ownership of cloned files to the target deployment user
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.dotfiles"

# Copy configurations carefully targeting the variable profile path
cp "$USER_HOME/.dotfiles/.profile" "$USER_HOME/"
rm -f "$USER_HOME/.bashrc"
cp "$USER_HOME/.dotfiles/.bashrc" "$USER_HOME/"
cp "$USER_HOME/.dotfiles/.bash_profile" "$USER_HOME/"
cp "$USER_HOME/.dotfiles/.Xresources" "$USER_HOME/"
cp "$USER_HOME/.dotfiles/.Xdefaults" "$USER_HOME/"

# Stow configurations relative to the correct target profile
cd "$USER_HOME/.dotfiles/stow"
sudo -u "$USERNAME" stow -t "$USER_HOME" */

# Apply user identification updates
git config --global user.email "kleshas@mailbox.org"
git config --global user.name "kleshas"

# ==> System Administration Task Configurations
echo "==> Configuring system operations..."
sudo pacman -Sc --noconfirm

# Configure Reflector automation
sudo mkdir -p /etc/xdg/reflector
echo "--protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" | sudo tee /etc/xdg/reflector/reflector.conf

# Manage system services
sudo systemctl enable reflector.service
sudo systemctl enable cups.service
sudo systemctl enable fstrim.timer
sudo systemctl enable prelockd.service

# Kernel module rules
echo "drivetemp" | sudo tee /etc/modules-load.d/modules.conf

# Dynamic file concatenation targeting the explicit script runtime variables
sudo bash -c "cat $USER_HOME/.dotfiles/crypttab > /etc/crypttab"
sudo bash -c "cat $USER_HOME/.dotfiles/fstab >> /etc/fstab"

# DNS resolver layout setup
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Persistent encryption storage performance settings
sudo cryptsetup --allow-discards --persistent refresh root || echo "Warning: Root is not managed via LUKS or device is busy."

echo "==> Installation complete! Please reboot your system."
