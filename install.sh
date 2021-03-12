#!/bin/bash
	exec &> >(tee -a ~/error.log)
	sudo timedatectl set-ntp true
	sudo pacman -Syu
	yay xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau radeon-profile-daemon-git
  	yay i3-gaps i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 termite feh rofi
	yay alsa-utils pavucontrol pulseaudio deadbeef smplayer
	yay conky-git hddtemp wget
	yay downgrade sysstat mlocate dunst grsync htop reflector redshift pacman-contrib picom linux-headers sddm
	yay electronmail thunderbird hunspell-en_CA hyphen-en firefox libreoffice-fresh zathura
	yay geany geany-themes
	yay cups hplip
	yay input-wacom-dkms xf86-input-wacom xf86-wacom-list
	yay lutris steam winetricks multimc jdk8-openjdk
	yay mcomix gthumb gnome-screenshot xnconvert calibre
	yay noto-fonts-emoji numix-circle-arc-icons-git arc-gtk-theme
	yay pcmanfm-gtk3 file-roller gvfs unrar
	yay streamlink-twitch-gui chatty
	yay ttf-dejavu -S ttf-droid ttf-liberation ttf-ms-fonts
	yay veracrypt cherrytree android-file-transfer keepassxc qbittorrent wpgtk-git krita
	
#Pacman doesn't clean out the folder where it keeps downloaded packages. It's smart to run this command to clean it out from time to time.
    	sudo pacman -Sc
#Font configuration
	sudo ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
#dotfiles
	cp -r ~/.dotfiles/config/ ~/.config
	chmod +x ~/.config/i3/volume
	rm ~/.bashrc
	rm ~/.bash_profile
	cp ~/.dotfiles/.bashrc ~/
	cp ~/.dotfiles/.bash_profile ~/
	cp ~/.dotfiles/.Xresources ~/
	chmod +x ~/.config/i3/ConkyMatic-master/conkymatic.sh
	cp ~/.dotfiles/backup.sh ~/
	cp ~/.dotfiles/kamvas.sh ~/
	chmod +x ~/kamvas.sh
#system stuff
	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
	echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf
	echo "Storage=none" |sudo tee -a /etc/systemd/coredump.conf
	echo "--country US --protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist
" |sudo tee /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.service
	sudo systemctl enable reflector.timer
	sudo systemctl enable cups.service
	sudo systemctl enable radeon-profile-daemon.service
	sudo systemctl enable fstrim.timer
	sudo systemctl enable sddm.service
