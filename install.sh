	sudo timedatectl set-ntp true
	sudo pacman -Syu
	sudo pacman -S --noconfirm reflector
	sudo reflector --country 'United States' --age 12 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
	sudo pacman -S --noconfirm xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server
    	sudo pacman -S --noconfirm lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau
    	sudo pacman -S --noconfirm i3-gaps
    	yay i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 termite feh wpgtk-git
	sudo pacman -S --noconfirm lightdm lightdm-gtk-greeter
	sudo systemctl enable lightdm.service
	sudo pacman -S --noconfirm alsa-utils  
	sudo pacman -S --noconfirm android-file-transfer
	sudo pacman -S --noconfirm arc-gtk-theme
	sudo pacman -S --noconfirm calibre
	yay chatty
	yay cherrytree-bin
	yay conky-git
	sudo pacman -S --noconfirm cups
	sudo pacman -S --noconfirm deadbeef
	sudo pacman -S --noconfirm dunst
	yay electronmail
	yay evince-light
	sudo pacman -S --noconfirm file-roller
	sudo pacman -S --noconfirm firefox
	sudo pacman -S --noconfirm grsync
	sudo pacman -S --noconfirm gvfs
	sudo pacman -S --noconfirm hddtemp
	sudo pacman -S --noconfirm hplip
	sudo pacman -S --noconfirm htop
	sudo pacman -S --noconfirm hunspell-en_CA
	sudo pacman -S --noconfirm jdk8-openjdk
	sudo pacman -S --noconfirm keepassxc
	sudo pacman -S --noconfirm krita
	sudo pacman -S --noconfirm libreoffice-fresh
	sudo pacman -S --noconfirm lutris
	sudo pacman -S --noconfirm mlocate
	sudo updatedb
	yay multimc
	sudo pacman -S --noconfirm noto-fonts-emoji
	sudo pacman -S --noconfirm ntfs-3g
	yay numix-circle-arc
	sudo pacman -S --noconfirm pacman-contrib
	sudo pacman -S --noconfirm pavucontrol
	sudo pacman -S --noconfirm pcmanfm-gtk3
	sudo pacman -S --noconfirm pulseaudio
	yay radeon-profile-daemon-git
	sudo systemctl enable radeon-profile-daemon.service
	sudo pacman -S --noconfirm redshift
	sudo pacman -S --noconfirm rofi
	mkdir ~/.config/rofi
	touch ~/.config/rofi/config
	wpg-install.sh -r
	wpg-install.sh -d
	sudo pacman -S --noconfirm smplayer
	sudo pacman -S --noconfirm steam
	sudo pacman -S --noconfirm streamlink-twitch-gui
	yay sublime-text-dev
	sudo pacman -S --noconfirm sysstat
	sudo pacman -S --noconfirm thunderbird
	sudo pacman -S --noconfirm transmission-gtk
	sudo pacman -S --noconfirm ttf-dejavu
	sudo pacman -S --noconfirm ttf-droid
	sudo pacman -S --noconfirm ttf-liberation
	yay ttf-ms-fonts
	sudo pacman -S --noconfirm unrar
	sudo pacman -S --noconfirm veracrypt
	sudo pacman -S --noconfirm wget
	sudo pacman -S --noconfirm winetricks
	sudo pacman -S --noconfirm xdotool
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
	mkdir ~/.chatty
	ln -sv ~/.dotfiles/chatty/settings ~/.chatty
	mkdir ~/.config/cherrytree
	ln -sv ~/.dotfiles/cherrytree/config.cfg ~/.config/cherrytree
	mkdir ~/.config/dunst
	ln -sv ~/.dotfiles/dunst/dunstrc ~/.config/dunst
	cd ~/.config
	ln -sv ~/.dotfiles/i3 .
	chmod +x ~/.config/i3/volume
	mkdir ~/.config/lutris
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
	echo "--save /etc/pacman.d/mirrorlist --country 'United States' --protocol https --age 12 --sort rate --latest 5" |sudo tee -a /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.timer
