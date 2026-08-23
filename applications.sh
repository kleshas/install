#!/usr/bin/env bash

    set -euo pipefail
	HOSTNAME="$1"
	USERNAME="$2"

	sudo pacman -Sy

	# --- APP CONFIGURATION LISTS ---
	# Official repository packages (Installed via pacman)
	PACMAN_APPS=(
	lib32-mesa
	xf86-video-amdgpu
	vulkan-radeon
	lib32-vulkan-radeon
	libva-mesa-driver
	lib32-libva-mesa-driver
	smartmontools
	mesa
	vulkan-icd-loader
	lib32-vulkan-icd-loader
	alsa-utils
	pavucontrol
	pipewire
	pipewire-pulse
	pipewire-alsa
	lib32-pipewire
	mpv
	conky
	hddtemp
	wget
	nvme-cli
	sysstat
	dunst
	grsync
	htop
	reflector
	pacman-contrib
	linux-headers
	man-db
	ncdu
	btrfs-progs
	kitty
	polkit-gnome
	thunderbird
	hunspell-en_ca
	hyphen-en
	firefox
	libreoffice-fresh
	zathura
	hplip
	cups
	lutris
	steam
	jdk8-openjdk
	jdk-openjdk
	gthumb
	calibre
	feh
	noto-fonts-emoji
	ttf-dejavu
	ttf-droid
	ttf-liberation
	thunar
	xarchiver
	thunar-archive-plugin
	gvfs
	unrar
	grim
	vulkan-intel
	lib32-vulkan-intel
	lib32-gnutls
	lib32-libpulse
	wine-staging
	mpg123
	lib32-mpg123
	lib32-libxcomposite
	lib32-libxinerama
	opencl-icd-loader
	lib32-opencl-icd-loader
	lib32-libxslt
	lib32-libva
	lib32-gtk3
	otf-montserrat
	android-file-transfer
	keepassxc
	qbittorrent
	virtualbox
	obsidian
	geany
	geany-plugins
	pigz
	pbzip2
	)

	# AUR repository packages (Installed via yay)
	AUR_APPS=(
    amdgpu_top
	prelockd
	tartube
	downgrade
	prismlauncher
	heroic-games-launcher-bin
	mcomix
	xnconvert
	protontricks
	gnucash
	swaytools
	stow
	amdsmi
	imagemagick
	nwg-look
	slurp
	ydotool
	evtest
	otf-font-awesome
	waybar
	wofi
	xorg-xwayland
	xorg-xlsclients
	qt5-wayland
	qt6-wayland
	glfw-wayland
	gammastep
	swaylock-effects
	swaybg
	xdg-desktop-portal-gtk
	wl-clipboard
	catppuccin-gtk-theme-mocha
	catppuccin-gtk-theme-frappe
	catppuccin-gtk-theme-macchiato
	qt5ct
	catppuccin-qt5ct-git
	ttf-jetbrains-mono-nerd
	bibata-cursor-theme-bin
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
