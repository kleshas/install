#!/bin/bash
# uncomment to view debugging information 
#set -xeuo pipefail

#check if we're root
if [[ "$UID" -ne 0 ]]; then
    echo "This script needs to be run as root!" >&2
    exit 3
fi

### Config options
target="/dev/nvme0n1p3"
locale="en_CA.UTF-8"
keymap="us"
timezone="America/Vancouver"
hostname=$(date +%Y%b)
username="bhava"
#SHA512 hash of password. To generate, run 'mkpasswd -m sha-512', don't forget to prefix any $ symbols with \ . The entry below is the hash of 'password'
#user_password="\$6\$/VBa6GuBiFiBmi6Q\$yNALrCViVtDDNjyGBsDG7IbnNR0Y/Tda5Uz8ToyxXXpw86XuCVAlhXlIvzy1M8O.DWFB6TRCia0hMuAJiXOZy/"
user_password="\$6\$4HsM2SKYvvmIrYhC\$xffHDbqkJBpGN1ihmJ46PvPacgEztIVheUgYXc1jwZ6LzdPa9c5cuKk6jPeZEKjn2GNijK5SI/9vAuzQT/Rei0"

# Partition
echo "Creating partitions..."
#sgdisk -Z "$target"
sgdisk -d 1 -d 2 "$target"
sgdisk \
    -n1:0:+512M  -t1:ef00 -c1:boot \
    -N2          -t2:8304 -c2:linux \
    "$target"
    
# Reload partition table
sleep 2
partprobe -s "$target"
sleep 2
echo "Encrypting root partition..."

#Encrypt the root partition. prompt for crypt password
cryptsetup luksFormat /dev/disk/by-partlabel/linux
cryptsetup luksOpen /dev/disk/by-partlabel/linux root

echo "Making File Systems..."
# Create file systems
mkfs.fat -F32 -n EFISYSTEM /dev/disk/by-partlabel/boot
mkfs.ext4 -L linux /dev/mapper/root

# mount the root, and create + mount the EFI directory
echo "Mounting File Systems..."
mount /dev/mapper/root /mnt
mkdir /mnt/boot
mount /dev/disk/by-partlabel/boot /mnt/boot

#Update pacman mirrors and then pacstrap base install
echo "Pacstrapping..."
reflector --country CA --age 24 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt base base-devel linux linux-firmware intel-ucode nano cryptsetup 
genfstab -pU /mnt >> /mnt/etc/fstab

echo "Setting up environment..."
arch-chroot /mnt hwclock --systohc --utc
#set up locale/env
#add our locale to locale.gen
sed -i -e "/^#"$locale"/s/^#//" /mnt/etc/locale.gen
#remove any existing config files that may have been pacstrapped, systemd-firstboot will then regenerate them
rm /mnt/etc/{machine-id,localtime,hostname,shadow,locale.conf} ||
systemd-firstboot --root /mnt \
	--keymap="$keymap" --locale="$locale" \
	--locale-messages="$locale" --timezone="$timezone" \
	--hostname="$hostname" --setup-machine-id \
	--welcome=false
arch-chroot /mnt locale-gen
echo "Configuring for first boot..."

#add the local user
echo -e "[ * ]Adding user"
read -rp "Enter your desired username:" user_name
arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash "${user_name}"
arch-chroot /mnt passwd "${user_name}"

#uncomment the wheel group in the sudoers file
sed -i -e '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers
echo "LANG="$username" ALL=(ALL:ALL) NOPASSWD: /usr/bin/nvme" |sudo tee -a /mnt/etc/sudoers

#change the HOOKS in mkinitcpio.conf
sed -i 's/keymap consolefont/vdconsole encrypt/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux
 
#enable the services we will need on start up
echo "Enabling services..."
systemctl --root /mnt enable systemd-resolved systemd-networkd
cat <<EOF > /mnt/etc/systemd/network/20-wired.network
	[Match]
	Name=enp8s0
	[Network]
	DHCP=yes
	IPv6PrivacyExtensions=yes
EOF

#improve compilation speeds
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i 's/-march=[^ ]* -mtune=[^ ]*/-march=native/' /mnt/etc/makepkg.conf
sed -i 's/^#MAKEFLAGS=-j2/MAKEFLAGS=-j$(nproc)/' /mnt/etc/makepkg.conf
sed -i 's/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=0)/' /mnt/etc/makepkg.conf

#install the systemd-boot bootloader
arch-chroot /mnt bootctl install
arch-chroot /mnt rm -f /boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/loader.conf
	default arch
	timeout 3
	editor 0
EOF
cat <<EOF > /mnt/boot/loader/entries/arch.conf
	title arch
	linux /vmlinuz-linux
	initrd /intel-ucode.img
	initrd /initramfs-linux.img
EOF

echo "options cryptdevice=PARTUUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p2):root:allow-discards root=/dev/mapper/root rw quiet split_lock_detect=off loglevel=3 ibt=off" >> /mnt/boot/loader/entries/arch.conf

arch-chroot /mnt <<EOF
	pacman -Syu
	pacman -S git
	git clone https://aur.archlinux.org/yay-bin.git
	cd yay-bin
	makepkg -si
	mkdir ~/.dotfiles
	git clone https://gitlab.com/kleshas/dots.git ~/.dotfiles
	bash ~/.dotfiles/.scripts/install.sh
EOF

#lock the root account
arch-chroot /mnt usermod -L root
#and we're done


echo "-----------------------------------"
echo "- Install complete. Rebooting.... -"
echo "-----------------------------------"
sleep 10
sync
reboot

