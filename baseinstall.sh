#!/usr/bin/env bash

# Exit on error, pipe failure, or unset variables
set -euo pipefail

# --- LOGGING & COLOR DEFINITIONS (Inspired by amelia.sh) ---
LOG_FILE="/tmp/arch-install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

# --- CONFIGURATION VARIABLES ---
HOSTNAME=$(date +%Y%b)
TIMEZONE="America/Vancouver"
LOCALE="en_CA.UTF-8"
MAPPER_NAME="cryptroot"

# --- CLEANUP TRAP (Inspired by amelia.sh) ---
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Installation failed or was interrupted! Cleaning up..."
    else
        ok "Installation finished cleanly. Running final unmount sequence..."
    fi

    # Synchronize disk cache
    sync

    # Safely unmount target filesystems if mounted
    if mountpoint -q /mnt/boot 2>/dev/null; then
        umount /mnt/boot || true
    fi
    if mountpoint -q /mnt 2>/dev/null; then
        umount /mnt || true
    fi

    # Safely close cryptsetup mapper if open
    if [ -b "/dev/mapper/${MAPPER_NAME}" ]; then
        cryptsetup close "${MAPPER_NAME}" || true
    fi

    if [ $exit_code -ne 0 ]; then
        error "Cleanup complete. Check ${LOG_FILE} for details."
        exit $exit_code
    fi
}

trap cleanup EXIT INT TERM

# --- DRIVE SELECTION LOOP ---
echo -e "${BLUE}=== Available Storage Drives ===${NC}"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop"
echo ""

until [ -n "${DISK:-}" ] && [ -b "${DISK}" ]; do
    read -p "Enter the device path to install Arch Linux on (e.g., /dev/sda or /dev/nvme0n1): " DISK
    if [ ! -b "$DISK" ]; then
        error "$DISK is not a valid block device. Please try again."
    fi
done

# Ensure the selected target isn't currently mounted
if grep -q "$DISK" /proc/mounts; then
    error "Target disk $DISK (or one of its partitions) is currently mounted. Please unmount it first."
    exit 1
fi

# --- USER INPUT PROMPTS ---
echo ""
until [ -n "${USER_NAME:-}" ]; do
    read -p "Enter the non-root username to create: " USER_NAME
    if [ -z "$USER_NAME" ]; then
        warn "Username cannot be empty."
    fi
done

# Prompt for Root Password
echo ""
while true; do
    read -sp "Enter root password: " ROOT_PASSWORD; echo ""
    read -sp "Confirm root password: " ROOT_PASSWORD_CONFIRM; echo ""
    if [ -z "$ROOT_PASSWORD" ]; then
        warn "Password cannot be empty."
    elif [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
        break
    else
        warn "Passwords do not match. Please try again."
    fi
done

# Prompt for User Password
echo ""
while true; do
    read -sp "Enter password for $USER_NAME: " USER_PASSWORD; echo ""
    read -sp "Confirm password for $USER_NAME: " USER_PASSWORD_CONFIRM; echo ""
    if [ -z "$USER_PASSWORD" ]; then
        warn "Password cannot be empty."
    elif [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
        break
    else
        warn "Passwords do not match. Please try again."
    fi
done

# Prompt for LUKS Passphrase
echo ""
while true; do
    read -sp "Enter LUKS encryption passphrase for root partition: " LUKS_PASSPHRASE; echo ""
    read -sp "Confirm LUKS encryption passphrase: " LUKS_PASSPHRASE_CONFIRM; echo ""
    if [ -z "$LUKS_PASSPHRASE" ]; then
        warn "Passphrase cannot be empty."
    elif [ "$LUKS_PASSPHRASE" = "$LUKS_PASSPHRASE_CONFIRM" ]; then
        break
    else
        warn "Passphrases do not match. Please try again."
    fi
done

# --- CONFIRMATION SUMMARY ---
echo ""
info "Current layout of $DISK:"
lsblk "$DISK"
echo ""

echo "-----------------------------------------------------------------"
echo "Target User: $USER_NAME"
echo "Target Locale: $LOCALE"
echo "Target Hostname: $HOSTNAME"
echo "Target Timezone: $TIMEZONE"
echo "Bootloader: systemd-boot"
echo "Networking: systemd-networkd + systemd-resolved"
echo "Initramfs Hooks: microcode before autodetect"
echo "Root Partition ($DISK 2): LUKS Encrypted"
warn "WARNING: Partitions 1 and 2 on $DISK will be permanently wiped!"
echo "Partition 3+ will remain untouched."
echo "-----------------------------------------------------------------"
read -p "Are you sure you want to proceed? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    warn "Installation aborted by user."
    exit 0
fi

info "1. Setting System Clock & Enabling Parallel Downloads"
timedatectl set-ntp true
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

info "2. Partitioning Disk ($DISK)"
sgdisk -d 1 -d 2 "$DISK" || true
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0     -t 2:8300 "$DISK"

if [[ "$DISK" =~ "nvme" ]]; then
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
fi

partprobe "$DISK"

info "3. Encrypting and Opening Root Partition"
echo -n "$LUKS_PASSPHRASE" | cryptsetup luksFormat --type luks2 "$PART_ROOT" -
echo -n "$LUKS_PASSPHRASE" | cryptsetup open "$PART_ROOT" "$MAPPER_NAME" -

info "4. Formatting Partitions"
mkfs.fat -F32 "$PART_BOOT"
mkfs.ext4 -F "/dev/mapper/$MAPPER_NAME"

info "5. Mounting Filesystems"
mount "/dev/mapper/$MAPPER_NAME" /mnt
mkdir -p /mnt/boot
mount "$PART_BOOT" /mnt/boot

info "6. Bootstrapping Base System"
pacstrap -K /mnt base linux linux-firmware intel-ucode cryptsetup base-devel sudo nano

info "7. Generating Fstab"
genfstab -U /mnt >> /mnt/etc/fstab

ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")

info "8. Configuring System via Chroot"
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname

echo "root:$ROOT_PASSWORD" | chpasswd

useradd -m -G wheel -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable fstrim.timer

cat <<NETWORK > /etc/systemd/network/20-wired.network
[Match]
Name=en*

[Network]
DHCP=yes
NETWORK

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sed -i 's/^HOOKS=(.*)/HOOKS=(base systemd microcode autodetect modconf block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

bootctl install

cat <<LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
LOADER

cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=$ROOT_UUID=$MAPPER_NAME rd.luks.options=allow-discards root=/dev/mapper/$MAPPER_NAME rw
ENTRY

sync
EOF

ok "System configuration completed successfully."
