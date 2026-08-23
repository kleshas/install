#!/usr/bin/env bash

    set -euo pipefail
	HOSTNAME="$1"
	USERNAME="$2"

	sudo pacman -Sy

	# --- APP CONFIGURATION LISTS ---
	# Official repository packages (Installed via pacman)
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

	# AUR repository packages (Installed via yay)
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

	echo "==> Installing yay (AUR Helper)"
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin || exit
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
	
	echo "==> Installing packages..."
    sudo pacman -S --needed --noconfirm "${PACMAN_APPS[@]}"
	yay -S --needed --noconfirm \
        --answerclean All \
        --answerdiff None \
        --answerupgrade None \
        "${AUR_APPS[@]}"
	yay --save --answerclean None --answerdiff None

# Clone the dotfiles repository securely
    echo "==> Cloning dotfiles repo"
    git clone https://github.com/kleshas/dotfiles ~/.dotfiles

	cp ~/.dotfiles/.profile ~/
	rm ~/.bashrc
	cp ~/.dotfiles/.bashrc ~/
	cp ~/.dotfiles/.bash_profile ~/
	cp ~/.dotfiles/.Xresources ~/
	cp ~/.dotfiles/.Xdefaults ~/
	
	cd ~/.dotfiles/stow
	stow -t ../.. */

	git config --global user.email "kleshas@mailbox.org"
	git config --global user.name "kleshas"

#system stuff
	sudo pacman -Sc
	echo "--protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" |sudo tee /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.service
	sudo systemctl enable cups.service
	sudo systemctl enable fstrim.timer
	sudo systemctl enable prelockd.service
	echo "drivetemp" |sudo tee /etc/modules-load.d/modules.conf
	sudo bash -c "cat /home/bhava/.dotfiles/crypttab > /etc/crypttab"
	sudo bash -c "cat /home/bhava/.dotfiles/fstab >> /etc/fstab"
	sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
	sudo cryptsetup --allow-discards --persistent refresh root
