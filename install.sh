	sudo timedatectl set-ntp true
	sudo pacman -Syu
	sudo pacman -S reflector
	sudo reflector --country 'United States' --age 12 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
	sudo pacman -S git
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si

	sudo pacman -S xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server
    sudo pacman -S lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau

    yay -S i3-gaps
    yay -S i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 termite feh wpgtk-git
	yay -S lightdm lightdm-gtk-greeter
	sudo systemctl enable lightdm.service

	sudo pacman -S --noconfirm alsa-utils  
	sudo pacman -S --noconfirm android-file-transfer
	sudo pacman -S --noconfirm arc-gtk-theme
	sudo pacman -S --noconfirm calibre-python3
	sudo calibre-alternatives set 3
	sudo pacman -S --noconfirm chatty
	sudo pacman -S --noconfirm cherrytree-bin
	sudo pacman -S --noconfirm conky-git
	sudo pacman -S --noconfirm cups
	sudo pacman -S --noconfirm deadbeef
	sudo pacman -S --noconfirm dunst
	sudo pacman -S --noconfirm electronmail and tutanota
	sudo pacman -S --noconfirm evince-light
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
	sudo pacman -S --noconfirm mullvad-vpn-bin
	sudo pacman -S --noconfirm ultimc
	sudo pacman -S --noconfirm noto-fonts-emoji
	sudo pacman -S --noconfirm ntfs-3g
	sudo pacman -S --noconfirm numix-circle-arc
	sudo pacman -S --noconfirm pacman-contrib
	sudo pacman -S --noconfirm pavucontrol
	sudo pacman -S --noconfirm pcmanfm-gtk3
	sudo pacman -S --noconfirm pulseaudio
	sudo pacman -S --noconfirm radeon-profile-daemon-git
	sudo pacman -S --noconfirm redshift
	sudo pacman -S --noconfirm rofi
	touch ~/.config/rofi/config
	sudo pacman -S --noconfirm smplayer
	sudo pacman -S --noconfirm steam
	sudo pacman -S --noconfirm streamlink-twitch-gui
	sudo pacman -S --noconfirm sublime-text-dev
	sudo pacman -S --noconfirm sysstat
	sudo pacman -S --noconfirm thunderbird
	sudo pacman -S --noconfirm transmission-gtk
	sudo pacman -S --noconfirm ttd-dejavu
	sudo pacman -S --noconfirm ttf-droid
	sudo pacman -S --noconfirm ttf-liberation
	sudo pacman -S --noconfirm ttf-ms-fonts
	sudo pacman -S --noconfirm unrar
	sudo pacman -S --noconfirm veracrypt
	sudo pacman -S --noconfirm wget
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

	git clone https://github.com/kleshas/install.git ~/.dotfiles
	mkdir ~/.chatty
	ln -sv ~/.dotfiles/chatty/settings ~/.chatty
	mkdir ~/.config/cherrytree
	ln -sv ~/.dotfiles/cherrytree/config.cfg ~/.config/cherrytree
	mkdir ~/.config/dunst
	ln -sv ~/.dotfiles/dunst/dunstrc ~/.config/dunst
	cd ~/.config
	ln -sv ~/.dotfiles/i3 .
	chmod +x ./config/i3/volume
	ln -sv ~/.dotfiles/lutris/lutris.conf ~/.config/lutris
	ln -sv ~/.dotfiles/smplayer/smplayer.ini ~/.config/smplayer
	mkdir ~/.config/termite
	ln -sv ~/.dotfiles/termite/config ~/.config/termite
	rm ~/.bashrc
	ln -sv ~/.dotfiles/.bashrc ~/
	ln -sv ~/.dotfiles/.Xresources ~/

	echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
	echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf
	echo "Storage=none" |sudo tee -a /etc/systemd/coredump.conf
	sudo systemctl daemon-reload
