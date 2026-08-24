#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- CONFIGURATION VARIABLES ---
HOSTNAME=$(date +%Y%b)
TIMEZONE="America/Vancouver"
LOCALE="en_CA.UTF-8"
MAPPER_NAME="cryptroot"

echo "=== Available Storage Drives ==="
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop"

echo ""
read -p "Enter the device path to install Arch Linux on (e.g., /dev/sda or /dev/nvme0n1): " DISK

# Check if drive exists
if [ ! -b "$DISK" ]; then
    echo "Error: $DISK is not a valid block device."
    exit 1
fi

# Prompt for username
echo ""
while [ -z "$USER_NAME" ]; do
    read -p "Enter the non-root username to create: " USER_NAME
    if [ -z "$USER_NAME" ]; then
        echo "Username cannot be empty. Please try again."
    fi
done

# Securely prompt for Root Password with confirmation
echo ""
while true; do
    read -sp "Enter root password: " ROOT_PASSWORD
    echo ""
    read -sp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo ""
    if [ -z "$ROOT_PASSWORD" ]; then
        echo "Password cannot be empty."
    elif [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Securely prompt for User Password with confirmation
echo ""
while true; do
    read -sp "Enter password for $USER_NAME: " USER_PASSWORD
    echo ""
    read -sp "Confirm password for $USER_NAME: " USER_PASSWORD_CONFIRM
    echo ""
    if [ -z "$USER_PASSWORD" ]; then
        echo "Password cannot be empty."
    elif [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Securely prompt for LUKS Encryption Passphrase with confirmation
echo ""
while true; do
    read -sp "Enter LUKS encryption passphrase for root partition: " LUKS_PASSPHRASE
    echo ""
    read -sp "Confirm LUKS encryption passphrase: " LUKS_PASSPHRASE_CONFIRM
    echo ""
    if [ -z "$LUKS_PASSPHRASE" ]; then
        echo "Passphrase cannot be empty."
    elif [ "$LUKS_PASSPHRASE" = "$LUKS_PASSPHRASE_CONFIRM" ]; then
        break
    else
        echo "Passphrases do not match. Please try again."
    fi
done

# Show existing partition structure for reference
echo ""
echo "Current layout of $DISK:"
lsblk "$DISK"
echo ""

# Confirmation warning
echo "-----------------------------------------------------------------"
echo "Target User will be set to: $USER_NAME"
echo "Target Locale will be set to: $LOCALE"
echo "Target Hostname will be set to: $HOSTNAME"
echo "Target Timezone will be set to: $TIMEZONE"
echo "Bootloader: systemd-boot"
echo "Networking: systemd-networkd + systemd-resolved"
echo "Initramfs Hooks: microcode before autodetect"
echo "Microcode Package: intel-ucode (embedded via hook)"
echo "Root Partition ($DISK 2) will be LUKS Encrypted!"
echo "WARNING: Partitions 1 and 2 on $DISK will be deleted and recreated!"
echo "Partition 3+ will remain untouched."
echo "-----------------------------------------------------------------"
read -p "Are you sure you want to proceed? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation aborted."
    exit 1
fi

echo "=== 1. Setting System Clock ==="
timedatectl set-ntp true

echo "=== 2. Re-partitioning Disk ($DISK) ==="
# Delete existing partitions 1 and 2 if they exist, then recreate them:
# - Delete 1 & 2 (-d 1 -d 2)
# - Partition 1: 512M at the start of the drive (EFI)
# - Partition 2: Fill remaining space up to partition 3 (Linux root)
sgdisk -d 1 -d 2 "$DISK" || true
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0     -t 2:8300 "$DISK"

# Handle NVMe vs standard block device naming for partitions
if [[ "$DISK" =~ "nvme" ]]; then
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
fi

# Inform OS of partition table changes
partprobe "$DISK"

echo "=== 3. Encrypting and Opening Root Partition ==="
echo -n "$LUKS_PASSPHRASE" | cryptsetup luksFormat --type luks2 "$PART_ROOT" -
echo -n "$LUKS_PASSPHRASE" | cryptsetup open "$PART_ROOT" "$MAPPER_NAME" -

echo "=== 4. Formatting Partitions ==="
mkfs.fat -F32 "$PART_BOOT"
mkfs.ext4 -F "/dev/mapper/$MAPPER_NAME"

echo "=== 5. Mounting Filesystems ==="
mount "/dev/mapper/$MAPPER_NAME" /mnt
mkdir -p /mnt/boot
mount "$PART_BOOT" /mnt/boot

echo "=== 6. Bootstrapping Base System ==="
pacstrap -K /mnt base linux linux-firmware intel-ucode cryptsetup base-devel sudo nano

echo "=== 7. Generating Fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

# Capture UUID of the raw encrypted partition (PART_ROOT)
ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")

echo "=== 8. Configuring System via Chroot ==="
arch-chroot /mnt /bin/bash <<EOF
set -e

# Timezone & Clock
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Root Password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create Non-Root User & Add to Sudoers
useradd -m -G wheel -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel

# Configure systemd-networkd & systemd-resolved
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Auto-configure DHCP on all Ethernet interfaces
cat <<NETWORK > /etc/systemd/network/20-wired.network
[Match]
Name=en*

[Network]
DHCP=yes
NETWORK

# Link systemd-resolved stub file for DNS resolution
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Configure mkinitcpio (microcode placed before autodetect embed microcode into initramfs)
sed -i 's/^HOOKS=(.*)/HOOKS=(base systemd microcode autodetect modconf block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Install systemd-boot EFI boot manager
bootctl install

# Configure loader.conf
cat <<LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
LOADER

# Create Arch Linux boot entry using unified initramfs image
cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=$ROOT_UUID=$MAPPER_NAME root=/dev/mapper/$MAPPER_NAME rw
ENTRY

EOF

echo "=== Installation Complete! ==="
echo "Created user: $USER_NAME"
echo "Locale set to: $LOCALE"
echo "Hostname set to: $HOSTNAME"
echo "Timezone set to: $TIMEZONE"
echo "Microcode: Intel (intel-ucode packed via HOOK)"
echo "Bootloader: systemd-boot"
echo "Networking: systemd-networkd + systemd-resolved"
echo "Initramfs Hooks: microcode before autodetect"
echo "Root Partition: Encrypted with LUKS"
echo "You can now unmount and reboot: umount -R /mnt && reboot"
