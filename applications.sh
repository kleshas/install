#!/bin/bash
# uncomment to view debugging information 
set -xeuo pipefail

### Desktop packages #####
pacs=(
	lib32-mesa
	xf86-video-amdgpu
	vulkan-radeon
	lib32-vulkan-radeon
	mesa-vdpau
	lib32-mesa-vdpau
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
	lib32-pipewire mpv
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
	pcmanfm-gtk3
	file-roller
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
	lib32-gst-plugins-base-libs
	cherrytree
	android-file-transfer
	keepassxc
	qbittorrent
	python-pywal
	virtualbox
	)
yay=(
	lact
	downgrade
	prismlauncher-bin
	heroic-games-launcher-bin
	mcomix
	xnconvert
	ttf-ms-fonts
	qt5-styleplugins
	streamlink-twitch-gui-bin
	chatty
	protontricks
	wpgtk
	)
	
#install the gui packages
echo "Installing GUI..."
arch-chroot /mnt timedatectl set-ntp true
arch-chroot /mnt pacman -Sy --needed "${pacs[@]}"
arch-chroot /mnt yay -S --needed "${yay[@]}"

#user-specific stuff
read -p "which username to install under? " username
HOME=/home/${username}
arch-chroot -u ${username} /mnt bash -c <<-EOF
	cd $HOME
	mkdir $HOME/YAY
	git clone https://aur.archlinux.org/yay-bin.git $HOME/YAY
	cd yay-bin
	makepkg -si
	mkdir ~/.dotfiles
	git clone https://gitlab.com/kleshas/dots.git ~/.dotfiles
	
   	sudo pacman -Sc
   	
	read -p "install i3? (y/n)" i3
	if [ "$i3" = "y" ]; then
		yay -S i3-wm i3blocks gnome-screenshot rofi i3lock-fancy-dualmonitors-git xorg-apps lxappearance-gtk3 numlockx xorg-xinit xterm xorg-server redshift-qt pamixer
	fi
	read -p "install sway? (y/n)" sway
	if [ "$sway" = "y" ]; then
		yay -S --needed sway swaytools slurp ydotool evtest otf-font-awesome waybar lxappearance wofi xorg-xwayland xorg-xlsclients qt5-wayland qt6-wayland glfw-wayland gammastep swaylock-effects-git swaybg xdg-desktop-portal-gtk
	fi

	cp -a ~/.dotfiles/.config/. ~/.config
	cp -a ~/.dotfiles/.chatty ~/
	rm ~/.bashrc
	cp ~/.dotfiles/.profile ~/
	cp ~/.dotfiles/.bashrc ~/
	cp ~/.dotfiles/.bash_profile ~/
	cp ~/.dotfiles/.Xresources ~/
	cp ~/.dotfiles/.Xdefaults ~/
	mkdir ~/.scripts
	cp -a ~/.dotfiles/.scripts/. ~/.scripts
	chmod +x ~/.scripts/*.sh
	cd ~/.dotfiles
	stow --adopt -vt ~ .
	git config --global user.email "kleshas@mailbox.org"
	git config --global user.name "kleshas"

	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf

	echo "--protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" |sudo tee /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.service
	sudo systemctl enable fstrim.timer

	wget https://mullvad.net/media/mullvad-code-signing.asc
	gpg2 --import mullvad-code-signing.asc
	gpg2 --edit-key A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF
	yay -S --needed mullvad-vpn-bin
	
	cat ~/.dotfiles/crypttab > /etc/crypttab
	cat ~/.dotfiles/fstab >> /etc/fstab
EOF

#lock the root account
#arch-chroot /mnt usermod -L root
#and we're done

echo "-----------------------------------"
echo "- Install complete. Rebooting.... -"
echo "-----------------------------------"
sleep 10
sync
reboot

