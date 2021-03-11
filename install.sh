	exec 2>&1 >~/error.log
	sudo timedatectl set-ntp true
	sudo pacman -Syu
	sudo yay -S xorg-xinit xorg-xrandr xorg-xinput xterm xorg-server lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa-vdpau lib32-mesa-vdpau radeon-profile-daemon-git
  	sudo yay -S i3-gaps i3blocks i3lock-fancy-dualmonitors-git xorg-xdpyinfo lxappearance-gtk3 termite feh rofi
	sudo yay -S alsa-utils pavucontrol pulseaudio deadbeef smplayer
	sudo yay -S conky-git hddtemp wget
	sudo yay -S downgrade sysstat mlocate dunst grsync htop reflector redshift pacman-contrib picom linux-headers sddm
	sudo yay -S electronmail thunderbird hunspell-en_CA hyphen-en firefox libreoffice-fresh zathura
	sudo yay -S geany geany-themes
	sudo yay -S cups hplip
	sudo yay -S input-wacom-dkms xf86-input-wacom xf86-wacom-list
	sudo yay -S lutris steam winetricks multimc jdk8-openjdk
	sudo yay -S mcomix gthumb gnome-screenshot xnconvert calibre
	sudo yay -S noto-fonts-emoji numix-circle-arc arc-gtk-theme
	sudo yay -S pcmanfm-gtk3 file-roller gvfs unrar
	sudo yay -S streamlink-twitch-gui chatty
	sudo yay -S ttf-dejavu -S ttf-droid ttf-liberation ttf-ms-fonts
	sudo yay -S veracrypt cherrytree android-file-transfer keepassxc qbittorrent wpgtk-git krita
	
#Pacman doesn't clean out the folder where it keeps downloaded packages. It's smart to run this command to clean it out from time to time.
    	sudo pacman -Sc
#Font configuration
	sudo ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
	sudo ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
#dotfiles
	mkdir ~/.config/rofi
	touch ~/.config/rofi/config
	ln -sv ~/.dotfiles/rofi/config ~/.config/rofi
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
	rm ~/.bash_profile
	ln -sv ~/.dotfiles/.bashrc ~/
	ln -sv ~/.dotfiles/.bash_profile ~/
	ln -sv ~/.dotfiles/.Xresources ~/
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
