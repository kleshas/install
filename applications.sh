#!/usr/bin/env bash

set -euo pipefail

# Ensure sudo credentials are cached upfront
sudo -v

# Keep sudo timestamp alive during execution
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "==> Configuring system DNS..."
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# ==> Automatically Enable Multilib Repository if missing or commented out
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "==> Enabling multilib repository..."
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
        sudo sed -i '/^\[multilib\]/{n;s/^#//}' /etc/pacman.conf
    else
        printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" | sudo tee -a /etc/pacman.conf
    fi
fi

# --- APP CONFIGURATION LISTS ---
# (Moved official Arch repo packages out of AUR array and into PACMAN_APPS)
PACMAN_APPS=(
    alsa-utils android-file-transfer btrfs-progs calibre conky cups dunst feh
    file-roller firefox gammastep geany geany-plugins git gnucash grim grsync gthumb gvfs
    hplip htop hunspell-en_ca hyphen-en imagemagick jdk-openjdk jdk8-openjdk
    keepassxc kitty lib32-gnutls lib32-gtk3 lib32-libva lib32-libva-mesa-driver
    lib32-libxcomposite lib32-libxinerama lib32-mesa lib32-opencl-icd-loader lib32-pipewire lib32-vulkan-icd-loader lib32-vulkan-intel
    lib32-vulkan-radeon libappindicator-gtk3 libreoffice-fresh libva-mesa-driver
    linux-headers lutris man-db mesa mpg123 mpv ncdu noto-fonts-emoji obsidian opencl-icd-loader otf-montserrat pacman-contrib pavucontrol
    pipewire pipewire-alsa pipewire-pulse qbittorrent qt5-wayland qt6-wayland reflector
    slurp smartmontools steam stow swaybg sysstat thunar thunar-archive-plugin
    thunderbird ttf-dejavu ttf-droid ttf-liberation unrar virtualbox vulkan-icd-loader
    vulkan-intel vulkan-radeon waybar wget wine-staging wl-clipboard wofi xf86-video-amdgpu
    xdg-desktop-portal-gtk xorg-xlsclients xorg-xwayland zathura
)

AUR_APPS=(
    amdsmi amdgpu_top bibata-cursor-theme-bin catppuccin-gtk-theme-frappe
    catppuccin-gtk-theme-macchiato catppuccin-gtk-theme-mocha catppuccin-qt5ct-git
    downgrade glfw-wayland heroic-games-launcher-bin mcomix nwg-look otf-font-awesome
    prelockd prismlauncher protontricks qt5ct swaylock-effects swaytools tartube
    ttf-jetbrains-mono-nerd xnconvert ydotool
)

# ==> Synchronize official packages
echo "==> Synchronizing system packages..."
sudo pacman -Syu --needed --noconfirm "${PACMAN_APPS[@]}"

# ==> Install yay safely inside an isolated temporary sandbox
if ! command -v yay &> /dev/null; then
    echo "==> Preparing AUR helper (yay)..."
    YAY_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$YAY_DIR"
    (
        cd "$YAY_DIR"
        makepkg -si --noconfirm
    )
    rm -rf "$YAY_DIR"
fi

# ==> Run AUR software provisioning routines
echo "==> Refreshing AUR applications..."
yay -S --needed --noconfirm \
    --answerclean All \
    --answerdiff None \
    --answerupgrade None \
    "${AUR_APPS[@]}"

# ==> Clone and configure profile runtime assets
echo "==> Resolving dotfiles tracking tree..."
if [ -d "$HOME/.dotfiles" ]; then
    git -C "$HOME/.dotfiles" pull
else
    git clone https://github.com/kleshas/dotfiles "$HOME/.dotfiles"
fi

# Deploy profile files safely with backup creation
for profile_file in .profile .bashrc .bash_profile .Xresources .Xdefaults; do
    if [ -f "$HOME/.dotfiles/$profile_file" ]; then
        [ -f "$HOME/$profile_file" ] && cp "$HOME/$profile_file" "$HOME/${profile_file}.bak"
        cp "$HOME/.dotfiles/$profile_file" "$HOME/"
    fi
done

# ==> Executing GNU Stow in isolated subshell
echo "==> Executing GNU Stow..."
if [ -d "$HOME/.dotfiles/stow" ]; then
    (
        cd "$HOME/.dotfiles/stow"
        stow --restow -t "$HOME" *
    )
fi

# Apply git identity settings
git config --global user.email "kleshas@mailbox.org"
git config --global user.name "kleshas"

# ==> System Configurations & Housekeeping
echo "==> Configuring system services & reflector..."
sudo mkdir -p /etc/xdg/reflector
echo "--protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" | sudo tee /etc/xdg/reflector/reflector.conf > /dev/null

sudo systemctl enable reflector.service cups.service fstrim.timer prelockd.service

# Append crypttab/fstab safely (prevents duplicate lines if re-run)
    cat "$HOME/.dotfiles/crypttab" | sudo tee /etc/crypttab > /dev/null

if [ -f "$HOME/.dotfiles/fstab" ]; then
    sudo cp /etc/fstab /etc/fstab.bak
    cat "$HOME/.dotfiles/fstab" | sudo tee -a /etc/fstab > /dev/null
fi

# Refresh LUKS discards
sudo cryptsetup --allow-discards --persistent refresh root || echo "Note: Root drive bypass optimized or non-LUKS."

# Clean cache at the end
echo "==> Sweeping pacman cache..."
sudo pacman -Sc --noconfirm

echo "==> Installation completely finished! System ready for restart."
