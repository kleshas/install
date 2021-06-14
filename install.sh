#!/bin/bash
	exec 2> >(tee -a ~/error.log)
	sudo timedatectl set-ntp true
	sudo pacman -Syu
	yay -S lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau radeon-profile-daemon-git kitty
  	yay -S alsa-utils pavucontrol pipewire pipewire-pulse pipewire-alsa lib32-pipewire deadbeef smplayer
	yay -S conky-git hddtemp wget
	yay -S downgrade sysstat mlocate dunst grsync htop reflector pacman-contrib linux-headers sddm ntfs-3g man-db
	yay -S electronmail thunderbird hunspell-en_ca hyphen-en firefox libreoffice-fresh zathura
	yay -S geany geany-themes
	yay -S cups hplip
	yay -S digimend-kernel-drivers-dkms-git input-wacom-dkms xf86-input-wacom
	yay -S lutris steam winetricks multimc jdk8-openjdk
	yay -S mcomix gthumb gnome-screenshot xnconvert calibre feh
	yay -S noto-fonts-emoji numix-circle-arc-icons-git arc-gtk-theme ttf-dejavu ttf-droid ttf-liberation ttf-ms-fonts
	yay -S pcmanfm-gtk3 file-roller gvfs unrar
	yay -S streamlink-twitch-gui chatty
	yay -S veracrypt cherrytree android-file-transfer keepassxc qbittorrent wpgtk-git krita
	
#Pacman doesn't clean out the folder where it keeps downloaded packages. It's smart to run this command to clean it out from time to time.
    sudo pacman -Sc
    	
#Font configuration
	sudo ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d

#install i3 and/or sway	
	read -p "install i3? (y/n)" RESP
	if [ "$RESP" = "y" ]; then
		yay -S i3-gaps i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 rofi picom xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server redshift
	fi
	
	read -p "install sway? (y/n)" REPLY
	if [ "$REPLY" = "y" ]; then
		yay -S sway otf-font-awesome waybar lxappearance wofi xorg-xwayland xorg-xlsclients qt5-wayland glfw-wayland wl-clipboard gammastep-indicator swaylock-blur-bin vlc
	fi
	
#dotfiles
	cp -r ~/.dotfiles/config/* ~/.config/
	mkdir ~/.chatty
	mv ~/.config/chatty/settings ~/.chatty/
	rm -f ~/.config/chatty
	chmod +x ~/.config/i3/pipewire-pulse
	rm ~/.bashrc
	cp ~/.dotfiles/.bashrc ~/
	cp ~/.dotfiles/.Xresources ~/
	mkdir ~/.scripts
	cp ~/.dotfiles/.scripts/* ~/.scripts
	chmod +x ~/.scripts/*.sh
	chmod +x ~/.scripts/ConkyMatic-master/conkymatic.sh
	
#system stuff
	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
	echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf
	echo "Storage=none" |sudo tee -a /etc/systemd/coredump.conf
	echo "--country US --protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist" |sudo tee /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.service
	sudo systemctl enable reflector.timer
	sudo systemctl enable cups.service
	sudo systemctl enable radeon-profile-daemon.service
	sudo systemctl enable fstrim.timer
	sudo systemctl enable sddm.service
	sudo modprobe -r hid-kye hid-uclogic hid-polostar hid-viewsonic
	systemctl --user enable --now pipewire-media-session.service
