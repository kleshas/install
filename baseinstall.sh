#!/bin/bash
# uncomment to view debugging information 
set -euo pipefail
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
echo -e "\e[1;31mCreating partitions...\n\e[0m"
lsblk
echo -e "\e[1;31mWhat drive do you want to install to? (e.g. nvme0n1) \n\e[0m"
read -p ": " target
#sgdisk -Z /dev/$target
sgdisk -d 1 -d 2 /dev/$target
sgdisk \
    -n1:0:+512M  -t1:ef00 -c1:boot \
    -N2          -t2:8304 -c2:linux \
    /dev/$target
    
# Reload partition table
sleep 2
partprobe -s /dev/$target
sleep 2

#Encrypt the root partition. prompt for crypt password
echo -e "\e[1;31mEncrypting the root partition...\e[0m\n"
cryptsetup luksFormat /dev/disk/by-partlabel/linux
echo -e "\e[1;31mOpening the root partition...\e[0m\n"
cryptsetup luksOpen /dev/disk/by-partlabel/linux root

echo -e "\e[1;31mMaking File Systems...\e[0m\n"
# Create file systems
mkfs.fat -F32 -n EFISYSTEM /dev/disk/by-partlabel/boot
mkfs.ext4 -L linux /dev/mapper/root

# mount the root, and create + mount the EFI directory
echo -e "\e[1;31mMounting File Systems...\e[0m\n"
mount /dev/mapper/root /mnt
mkdir /mnt/boot
mount /dev/disk/by-partlabel/boot /mnt/boot

#Update pacman mirrors and then pacstrap base install
echo -e "\e[1;31mPacstrapping...\e[0m\n"
pacstrap -K /mnt base base-devel linux linux-firmware intel-ucode nano cryptsetup git
genfstab -pU /mnt >> /mnt/etc/fstab
#Decrease writes to the USB by using the noatime option in fstab
sed -i 's/relatime/noatime/' /mnt/etc/fstab

echo -e "\e[1;31mSetting up environment...\e[0m\n"
echo $hostname > /mnt/etc/hostname
arch-chroot /mnt hwclock --systohc --utc
#set up locale/env
#add our locale to locale.gen
sed -i -e "/^#$locale/s/^#//" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo LANG=${locale} > /mnt/etc/locale.conf
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime

echo -e "\e[1;31mConfiguring for first boot...\e[0m\n"
#add the local user
echo -e "\e[1;31mLet's add a regular account.  What username?\e[0m"
read -p ": " username
arch-chroot /mnt useradd -mG wheel $username
arch-chroot /mnt passwd $username
echo -e "\e[1;31mChanging the root password...\e[0m\n"
arch-chroot /mnt passwd root

#uncomment the wheel group in the sudoers file
sed -i -e '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/s/^# //' /mnt/etc/sudoers
echo "$username ALL=(ALL:ALL) NOPASSWD: /usr/bin/nvme" |sudo tee -a /mnt/etc/sudoers
echo "$username ALL=(ALL:ALL) NOPASSWD: /usr/bin/smartctl" |sudo tee -a /mnt/etc/sudoers

#change the HOOKS in mkinitcpio.conf
sed -i 's/keymap/keymap encrypt/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux
 
#enable the services we will need on start up
echo -e "\e[1;31mEnabling services...\e[0m"
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
echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts

#improve compilation speeds
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i "/^#Color/s/^#//" /mnt/etc/pacman.conf
sed -i 's/-march=[^ ]* -mtune=[^ ]*/-march=native/' /mnt/etc/makepkg.conf
sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /mnt/etc/makepkg.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /mnt/etc/pacman.conf
sed -i 's/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=0)/' /mnt/etc/makepkg.conf
sed -i 's/^COMPRESSGZ=(gzip -c -f -n)/COMPRESSGZ=(pigz -c -f -n)/' /mnt/etc/makepkg.conf
sed -i 's/^COMPRESSBZ2=(bzip2 -c -f)/COMPRESSBZ2=(pbzip2 -c -f)/' /mnt/etc/makepkg.conf
sed -i 's/^COMPRESSZST=(zstd -c -T0 --ultra -20 -)/COMPRESSZST=(zstd -c -T0 -)/' /mnt/etc/makepkg.conf
sed -i 's/^OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)/OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)/' /mnt/etc/makepkg.conf
sed -i 's/^RUSTFLAGS="-Cforce-frame-pointers=yes"/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' /etc/makepkg.conf

#install the systemd-boot bootloader
arch-chroot /mnt bootctl install
arch-chroot /mnt rm -f /boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/loader.conf
	default arch
	timeout 0
	editor 0
EOF
cat <<EOF > /mnt/boot/loader/entries/arch.conf
	title arch
	linux /vmlinuz-linux
	initrd /intel-ucode.img
	initrd /initramfs-linux.img
EOF
echo "options cryptdevice=PARTUUID=$(blkid -s PARTUUID -o value /dev/${target}p2):root:allow-discards root=/dev/mapper/root rw quiet split_lock_detect=off loglevel=3 ibt=off" >> /mnt/boot/loader/entries/arch.conf

echo -e "\e[1;31mDownloading dotfiles...\e[0m\n"
arch-chroot /mnt su $username <<EOF
	mkdir ~/.dotfiles
	git clone https://gitlab.com/kleshas/dots.git ~/.dotfiles
EOF
echo -e "\n\n\n\e[1;31mReboot, log in as $username and run bash ~/.dotfiles/.scripts/install.sh\e[0m"
