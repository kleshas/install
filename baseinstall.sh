#!/bin/bash
# uncomment to view debugging information 
set -xeuo pipefail
timedatectl set-ntp true

#check if we're root
if [[ "$UID" -ne 0 ]]; then
    echo "This script needs to be run as root!" >&2
    exit 3
fi

### Config options
locale="en_CA.UTF-8"
hostname=$(date +%Y%b)

# Partition
lsblk
read -p "what drive to install to? " target
echo "Creating partitions..."
#sgdisk -Z /dev/"$target"
sgdisk -d 1 -d 2 /dev/"$target"
sgdisk \
    -n1:0:+512M  -t1:ef00 -c1:boot \
    -N2          -t2:8304 -c2:linux \
    /dev/"$target"
    
# Reload partition table
sleep 2
partprobe -s /dev/"$target"
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
pacstrap -K /mnt base base-devel linux linux-firmware intel-ucode nano cryptsetup git
genfstab -pU /mnt >> /mnt/etc/fstab
#Decrease writes to the USB by using the noatime option in fstab
sed -i 's/relatime/noatime/' /mnt/etc/fstab

echo "Setting up environment..."
echo "$hostname" > /mnt/etc/hostname
arch-chroot /mnt hwclock --systohc --utc
#set up locale/env
#add our locale to locale.gen
sed -i -e "/^#"$locale"/s/^#//" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo LANG=${locale} > /mnt/etc/locale.conf
ln -sf /mnt/usr/share/zoneinfo/America/Vancouver /mnt/etc/localtime

echo "Configuring for first boot..."
#add the local user
echo -e "[ * ]Adding user"
read -p "Username " username
arch-chroot /mnt useradd -mG wheel "$username"
arch-chroot /mnt passwd "$username"
arch-chroot /mnt passwd root

#uncomment the wheel group in the sudoers file
sed -i -e '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers
echo "$username" ALL=(ALL:ALL) NOPASSWD: /usr/bin/nvme" |sudo tee -a /mnt/etc/sudoers

#change the HOOKS in mkinitcpio.conf
sed -i 's/keymap/keymap encrypt/g' /mnt/etc/mkinitcpio.conf
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

#Put the following in the /etc/hosts file
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1  localhost" >> /mnt/etc/hosts
echo 127.0.1.1 "$hostname".localdomain "$hostname" >> /mnt/etc/hosts

#improve compilation speeds
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i 's/-march=[^ ]* -mtune=[^ ]*/-march=native/' /mnt/etc/makepkg.conf
sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS=-"-j$(nproc)"/' /mnt/etc/makepkg.conf
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

echo "options cryptdevice=PARTUUID=$(blkid -s PARTUUID -o value /dev/${target}p2):root:allow-discards root=/dev/mapper/root rw quiet split_lock_detect=off loglevel=3 ibt=off" >> /mnt/boot/loader/entries/arch.conf

read -rp "Do you want to setup the applications? [Y/n]:" apps
if [[ -z ${apps} || ${apps} == "y" || ${apps} == "Y" ]]; then
	curl -fSL https://raw.githubusercontent.com/kleshas/install/master/applications.sh > applications.sh
 	mv ./applications.sh /mnt/home/"${username}"
  	chmod +x /mnt/home/"${username}/applications.sh
	arch-chroot /mnt -u "${username}" -- bash /home/"${username}"/applications.sh
elif [[ ${apps} == "n" || ${apps} == "N" ]]; then
	echo -e "Skipping Rice Setup"
else
	echo -e "Not a valid option, Skipping Rice Setup"
fi
