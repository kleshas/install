	sudo timedatectl set-ntp true
	sudo pacman -Syu
	sudo pacman -S reflector
	sudo reflector --country 'United States' --age 12 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

	sudo pacman -S xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server
    	sudo pacman -S lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau

    	yay -S i3-gaps
    	yay -S i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 termite feh wpgtk-git
	yay -S lightdm lightdm-gtk-greeter
	sudo systemctl enable lightdm.service

	yay --noconfirm alsa-utils  
	yay --noconfirm android-file-transfer
	yay --noconfirm arc-gtk-theme
	yay --noconfirm calibre-python3
	sudo calibre-alternatives set 3
	yay --noconfirm chatty
	yay --noconfirm cherrytree-bin
	yay --noconfirm conky-git
	yay --noconfirm cups
	yay --noconfirm deadbeef
	yay --noconfirm dunst
	yay --noconfirm electronmail and tutanota
	yay --noconfirm evince-light
	yay --noconfirm file-roller
	yay --noconfirm firefox
	yay --noconfirm grsync
	yay --noconfirm gvfs
	yay --noconfirm hddtemp
	yay --noconfirm hplip
	yay --noconfirm htop
	yay --noconfirm hunspell-en_CA
	yay --noconfirm jdk8-openjdk
	yay --noconfirm keepassxc
	yay --noconfirm krita
	yay --noconfirm libreoffice-fresh
	yay --noconfirm lutris
	yay --noconfirm mlocate
	sudo updatedb
	yay --noconfirm mullvad-vpn-bin
	yay --noconfirm multimc
	yay --noconfirm noto-fonts-emoji
	yay --noconfirm ntfs-3g
	yay --noconfirm numix-circle-arc
	yay --noconfirm pacman-contrib
	yay --noconfirm pavucontrol
	yay --noconfirm pcmanfm-gtk3
	yay --noconfirm pulseaudio
	yay --noconfirm radeon-profile-daemon-git
	sudo systemctl enable radeon-profile-daemon.service
	yay --noconfirm redshift
	yay --noconfirm rofi
	mkdir ~/.config/rofi
	touch ~/.config/rofi/config
	wpg-install.sh -r
	wpg-install.sh -d
	yay --noconfirm smplayer
	yay --noconfirm steam
	yay --noconfirm streamlink-twitch-gui
	yay --noconfirm sublime-text-dev
	yay --noconfirm sysstat
	yay --noconfirm thunderbird
	yay --noconfirm transmission-gtk
	yay --noconfirm ttf-dejavu
	yay --noconfirm ttf-droid
	yay --noconfirm ttf-liberation
	yay --noconfirm ttf-ms-fonts
	yay --noconfirm unrar
	yay --noconfirm veracrypt
	yay --noconfirm wget
	yay --noconfirm xdotool

	sudo systemctl enable org.cups.cupsd.service
	sudo systemctl enable cups-browsed.service

#Pacman doesn't clean out the folder where it keeps downloaded packages. It's smart to run this command to clean it out from time to time.
    	sudo pacman -Sc --noconfirm

	sudo systemctl enable fstrim.timer

#Font configuration
	sudo ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
	
#dotfiles
	git clone https://github.com/kleshas/install.git ~/.dotfiles
	mkdir ~/.chatty
	ln -sv ~/.dotfiles/chatty/settings ~/.chatty
	mkdir ~/.config/cherrytree
	ln -sv ~/.dotfiles/cherrytree/config.cfg ~/.config/cherrytree
	mkdir ~/.config/dunst
	ln -sv ~/.dotfiles/dunst/dunstrc ~/.config/dunst
	cd ~/.config
	ln -sv ~/.dotfiles/i3 .
	chmod +x ~/.config/i3/volume
	ln -sv ~/.dotfiles/lutris/lutris.conf ~/.config/lutris
	mkdir ~/.config/smplayer
	ln -sv ~/.dotfiles/smplayer/smplayer.ini ~/.config/smplayer
	mkdir ~/.config/termite
	ln -sv ~/.dotfiles/termite/config ~/.config/termite
	rm ~/.bashrc
	ln -sv ~/.dotfiles/.bashrc ~/
	ln -sv ~/.dotfiles/.Xresources ~/
	
#system files
	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
	echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf
	echo "Storage=none" |sudo tee -a /etc/systemd/coredump.conf
	sudo systemctl daemon-reload
	echo "--save /etc/pacman.d/mirrorlist --country United States --protocol https --latest 5" |sudo tee -a /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.timer
