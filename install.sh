	exec 2>~/error.log
	sudo timedatectl set-ntp true
	sudo pacman -Syu
	sudo pacman -S reflector
	sudo reflector --country 'United States' --age 12 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
	sudo pacman -S xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server
    	sudo pacman -S lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau
    	sudo pacman -S i3-gaps
    	yay i3blocks
	yay i3lock-fancy-dualmonitors-git
	yay xorg-xdpyinfo
	yay lxappearance-gtk3
	yay termite
	yay feh
	yay wpgtk-git
	sudo pacman -S lightdm lightdm-gtk-greeter
	sudo systemctl enable lightdm.service
	sudo pacman -S alsa-utils  
	sudo pacman -S android-file-transfer
	sudo pacman -S arc-gtk-theme
	sudo pacman -S calibre
	yay chatty
	yay cherrytree
	yay conky-git
	sudo pacman -S cups
	sudo pacman -S deadbeef
	sudo pacman -S dunst
	yay electronmail
	yay evince-light
	sudo pacman -S file-roller
	sudo pacman -S firefox
	sudo pacman -S grsync
	sudo pacman -S gvfs
	sudo pacman -S hddtemp
	sudo pacman -S hplip
	sudo pacman -S htop
	sudo pacman -S hunspell-en_CA
	sudo pacman -S jdk8-openjdk
	sudo pacman -S keepassxc
	sudo pacman -S krita
	sudo pacman -S libreoffice-fresh
	sudo pacman -S lutris
	sudo pacman -S mlocate
	sudo updatedb
	yay multimc
	sudo pacman -S noto-fonts-emoji
	sudo pacman -S ntfs-3g
	yay numix-circle-arc
	sudo pacman -S pacman-contrib
	sudo pacman -S pavucontrol
	sudo pacman -S pcmanfm-gtk3
	sudo pacman -S pulseaudio
	yay radeon-profile-daemon-git
	sudo systemctl enable radeon-profile-daemon.service
	sudo pacman -S redshift
	sudo pacman -S rofi
	mkdir ~/.config/rofi
	touch ~/.config/rofi/config
	wpg-install.sh -r
	wpg-install.sh -d
	sudo pacman -S smplayer
	sudo pacman -S steam
	sudo pacman -S streamlink-twitch-gui
	yay sublime-text-dev
	sudo pacman -S sysstat
	sudo pacman -S thunderbird
	sudo pacman -S transmission-gtk
	sudo pacman -S ttf-dejavu
	sudo pacman -S ttf-droid
	sudo pacman -S ttf-liberation
	yay ttf-ms-fonts
	sudo pacman -S unrar
	sudo pacman -S veracrypt
	sudo pacman -S wget
	sudo pacman -S winetricks
	sudo pacman -S xdotool
	sudo systemctl enable org.cups.cupsd.service
	sudo systemctl enable cups-browsed.service
	sudo pacman -S linux-headers
    	yay --noconfirm digimend-kernel-drivers-dkms-git

    	sudo modprobe -r hid-kye hid-uclogic hid-polostar hid-viewsonic
	xinput map-to-output 'HID 256c:006e Pen Pen (0)' DisplayPort-2

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
	ln -sv ~/.dotfiles/i3 ~/.config
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
	chmod +x ~/.config/i3/ConkyMatic-master/conkymatic.sh
	cp ~/.dotfiles/lock.sh ~/
	cp ~/.dotfiles/backup.sh ~/
	cp ~/.dotfiles/xinput.sh ~/
#system files
	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
	echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf
	echo "Storage=none" |sudo tee -a /etc/systemd/coredump.conf
	sudo systemctl daemon-reload
	echo "--country 'United States' --protocol https --age 12 --sort rate --latest 5 --save /etc/pacman.d/mirrorlist
" |sudo tee /etc/xdg/reflector/reflector.conf
	sudo systemctl enable reflector.timer
