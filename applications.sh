#!/usr/bin/env bash

    set -euo pipefail
    hostname=$1
	username=$2

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
	lib32-giflib
	mpg123
	lib32-mpg123
	lib32-openal
	lib32-v4l-utils
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
	github-cli
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
	ttf-ms-fonts
	protontricks
	gnucash
	sway
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
	)

	
	echo "==> Installing yay (AUR Helper) as $username..."
	# Run the compile process as the non-root user since makepkg blocks root execution
	sudo -u "$username" bash <<EOF
	cd /home/$username
	git clone https://archlinux.org
	cd yay-bin
	makepkg -si --noconfirm
	cd ..
	rm -rf yay-bin
	EOF
	
	echo "==> Installing official Pacman packages..."
    sudo pacman -S --needed --noconfirm "${PACMAN_APPS[@]}"


	echo "==> Installing AUR apps via yay..."
	# Run as user, passing the array elements cleanly inside the user session
	yay -S --needed --noconfirm \
        --answeredbeforeclean All \
        --answereddiff None \
        --answerupgrade None \
        "${AUR_APPS[@]}"
	wget https://mullvad.net/media/mullvad-code-signing.asc
	gpg2 --import mullvad-code-signing.asc
	gpg2 --edit-key A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF
	yay -S mullvad-vpn-bin
	
DOTFILES_DIR="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/kleshas/dotfiles"

	# Clone the dotfiles repository securely
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "==> Cloning dotfiles repo to $DOTFILES_DIR..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    echo "==> Dotfiles directory already exists. Pulling latest updates..."
    cd "$DOTFILES_DIR" && git pull
fi

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
