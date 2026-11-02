#!/usr/bin/env bash

# ============================================================
# Arch Linux Automated Installer
# LUKS2 + Ext4 + systemd-boot + systemd initramfs
# ============================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------
# 1. CONFIGURATION
# ------------------------------------------------------------

LOG_FILE="/tmp/arch-install.log"

HOSTNAME="arch-$(date +%Y%m)"
TIMEZONE="America/Vancouver"
LOCALE="en_CA.UTF-8"

MAPPER_NAME="cryptroot"
EFI_SIZE="+512M"
MIN_ROOT_SIZE=$((20 * 1024 * 1024 * 1024))

INSTALL_DISK=""
USER_NAME=""

ROOT_PASSWORD=""
USER_PASSWORD=""
LUKS_PASSPHRASE=""

PART_BOOT=""
PART_ROOT=""
ROOT_UUID=""

MOUNTED=0
MAPPER_OPEN=0

# ------------------------------------------------------------
# 2. LOGGING
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# ------------------------------------------------------------
# 3. CLEANUP AND ERROR HANDLING
# ------------------------------------------------------------

cleanup() {
    local exit_code=$?

    trap - EXIT INT TERM

    unset ROOT_PASSWORD USER_PASSWORD LUKS_PASSPHRASE

    if (( exit_code != 0 )); then
        error "Installation failed. Exit code: $exit_code"
        error "Review $LOG_FILE"
    else
        ok "Installation completed. Cleaning up."
    fi

    sync

    if mountpoint -q /mnt/boot 2>/dev/null; then
        umount /mnt/boot || warn "Could not unmount /mnt/boot"
    fi

    if mountpoint -q /mnt 2>/dev/null; then
        umount /mnt || warn "Could not unmount /mnt"
    fi

    if (( MAPPER_OPEN )); then
        cryptsetup close "$MAPPER_NAME" || \
            warn "Could not close encrypted mapper"
    fi

    if (( exit_code == 0 )); then
        ok "Cleanup complete."
    else
        error "Cleanup complete. Installation was unsuccessful."
    fi

    exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

die() {
    error "$*"
    exit 1
}

# ------------------------------------------------------------
# 4. PRE-INSTALLATION CHECKS
# ------------------------------------------------------------

check_root() {
    [[ $EUID -eq 0 ]] || die "Run this script as root."
}

check_uefi() {
    [[ -d /sys/firmware/efi ]] || \
        die "System must be booted in UEFI mode."

    [[ -d /sys/firmware/efi/efivars ]] || \
        warn "EFI variables unavailable. NVRAM boot entry creation may fail."
}

check_commands() {
    local commands=(
        lsblk
        sgdisk
        partprobe
        udevadm
        blkid
        cryptsetup
        mkfs.fat
        mkfs.ext4
        mount
        umount
        pacstrap
        genfstab
        arch-chroot
        bootctl
        mkinitcpio
        timedatectl
        chpasswd
        visudo
        findmnt
        blockdev
    )

    local command

    for command in "${commands[@]}"; do
        command -v "$command" >/dev/null 2>&1 || \
            die "Required command missing: $command"
    done
}

check_timezone() {
    [[ -e "/usr/share/zoneinfo/$TIMEZONE" ]] || \
        die "Timezone does not exist: $TIMEZONE"
}

# ------------------------------------------------------------
# 5. DISK SELECTION AND VALIDATION
# ------------------------------------------------------------

select_disk() {
    echo
    info "Available physical disks:"
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    echo

    while true; do
        read -r -p "Enter target disk (e.g. /dev/nvme0n1): " INSTALL_DISK

        [[ -b "$INSTALL_DISK" ]] || {
            warn "Not a valid block device."
            continue
        }

        INSTALL_DISK=$(readlink -f "$INSTALL_DISK")

        [[ "$(lsblk -dn -o TYPE "$INSTALL_DISK")" == "disk" ]] || {
            warn "Select a whole disk, not a partition."
            continue
        }

        break
    done

    info "Selected disk: $INSTALL_DISK"
    lsblk "$INSTALL_DISK"
}

check_disk_safety() {
    info "Checking disk usage..."

    if lsblk -nrpo MOUNTPOINTS "$INSTALL_DISK" |
        grep -q '[^[:space:]]'; then
        die "The selected disk or one of its partitions is mounted."
    fi

    local device_major_minor

    while read -r device_major_minor; do
        if swapon --noheadings --raw --output MAJ:MIN |
            grep -Fxq "$device_major_minor"; then
            die "An active swap device belongs to the selected disk."
        fi
    done < <(lsblk -nrpo MAJ:MIN "$INSTALL_DISK")

    if [[ -e "/dev/mapper/$MAPPER_NAME" ]]; then
        die "Mapper $MAPPER_NAME already exists."
    fi

    if ! sgdisk -v "$INSTALL_DISK"; then
        die "GPT validation failed. Inspect the disk manually."
    fi

    ok "Disk safety checks passed."
}

# ------------------------------------------------------------
# 6. PRESERVE EXISTING PARTITIONS
# ------------------------------------------------------------

partition_snapshot() {
    local partition

    while read -r partition; do
        [[ "$partition" =~ ^[0-9]+$ ]] || continue
        (( partition >= 3 )) || continue

        echo "PARTITION $partition"

        sgdisk -i "$partition" "$INSTALL_DISK" |
            grep -E \
            'Partition GUID code:|Partition unique GUID:|First sector:|Last sector:|Partition name:'
    done < <(lsblk -nrpo PARTN "$INSTALL_DISK")
}

# ------------------------------------------------------------
# 7. USER INPUT
# ------------------------------------------------------------

collect_user_details() {
    echo

    while true; do
        read -r -p "Enter username: " USER_NAME

        if [[ "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] &&
            [[ "$USER_NAME" != "root" ]]; then
            break
        fi

        warn "Invalid username. Use lowercase letters, digits, _ or -."
    done

    echo

    while true; do
        read -r -s -p "Root password: " ROOT_PASSWORD
        echo
        read -r -s -p "Confirm root password: " confirm
        echo

        if [[ -z "$ROOT_PASSWORD" ]]; then
            warn "Password cannot be empty."
        elif [[ "$ROOT_PASSWORD" == "$confirm" ]]; then
            unset confirm
            break
        else
            warn "Passwords do not match."
        fi

        unset confirm
    done

    echo

    while true; do
        read -r -s -p "User password: " USER_PASSWORD
        echo
        read -r -s -p "Confirm user password: " confirm
        echo

        if [[ -z "$USER_PASSWORD" ]]; then
            warn "Password cannot be empty."
        elif [[ "$USER_PASSWORD" == "$confirm" ]]; then
            unset confirm
            break
        else
            warn "Passwords do not match."
        fi

        unset confirm
    done

    echo

    while true; do
        read -r -s -p "LUKS passphrase: " LUKS_PASSPHRASE
        echo
        read -r -s -p "Confirm LUKS passphrase: " confirm
        echo

        if [[ -z "$LUKS_PASSPHRASE" ]]; then
            warn "Passphrase cannot be empty."
        elif [[ "$LUKS_PASSPHRASE" == "$confirm" ]]; then
            unset confirm
            break
        else
            warn "Passphrases do not match."
        fi

        unset confirm
    done
}

# ------------------------------------------------------------
# 8. FINAL CONFIRMATION
# ------------------------------------------------------------

confirmation() {
    echo
    echo "============================================================"
    echo "              ARCH LINUX INSTALLATION"
    echo "============================================================"

    echo "Disk:             $INSTALL_DISK"
    echo "Username:         $USER_NAME"
    echo "Hostname:         $HOSTNAME"
    echo "Locale:           $LOCALE"
    echo "Timezone:         $TIMEZONE"
    echo "Bootloader:       systemd-boot"
    echo "Filesystem:       Ext4"
    echo "Encryption:       LUKS2"
    echo "Mapper:           $MAPPER_NAME"
    echo "Initramfs:        systemd + sd-encrypt"
    echo "Networking:       systemd-networkd"
    echo
    echo "Partitions 1 and 2 will be deleted and recreated."
    echo "Partitions 3 and above must remain unchanged."
    echo
    warn "THIS OPERATION IS DESTRUCTIVE."
    echo "============================================================"

    read -r -p "Type INSTALL to continue: " CONFIRM

    [[ "$CONFIRM" == "INSTALL" ]] || {
        warn "Installation cancelled."
        exit 0
    }
}

# ------------------------------------------------------------
# 9. SYSTEM CLOCK
# ------------------------------------------------------------

configure_clock() {
    info "Synchronizing system clock..."

    timedatectl set-ntp true

    ok "System clock configured."
}

# ------------------------------------------------------------
# 10. PARTITIONING
# ------------------------------------------------------------

partition_disk() {
    info "Recording existing partitions 3+..."

    local before after

    before=$(partition_snapshot)

    info "Deleting and recreating partitions 1 and 2..."

    sgdisk \
        --delete=1 \
        --delete=2 \
        --new=1:0:"$EFI_SIZE" \
        --typecode=1:ef00 \
        --change-name=1:EFI \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:cryptroot \
        "$INSTALL_DISK"

    partprobe "$INSTALL_DISK"
    udevadm settle

    sleep 2

    after=$(partition_snapshot)

    [[ "$before" == "$after" ]] || \
        die "Existing partitions 3+ changed. Stopping installation."

    PART_BOOT=$(lsblk -nrpo PATH,PARTN "$INSTALL_DISK" |
        awk '$2 == 1 {print $1; exit}')

    PART_ROOT=$(lsblk -nrpo PATH,PARTN "$INSTALL_DISK" |
        awk '$2 == 2 {print $1; exit}')

    [[ -b "$PART_BOOT" ]] || die "EFI partition was not created."
    [[ -b "$PART_ROOT" ]] || die "Root partition was not created."

    local root_size
    root_size=$(blockdev --getsize64 "$PART_ROOT")

    (( root_size >= MIN_ROOT_SIZE )) || \
        die "Root partition is smaller than 20 GiB."

    info "New partition layout:"
    lsblk "$INSTALL_DISK"

    ok "Partition creation and preservation checks passed."
}

# ------------------------------------------------------------
# 11. LUKS2 ENCRYPTION
# ------------------------------------------------------------

configure_encryption() {
    info "Creating LUKS2 encrypted root..."

    printf '%s' "$LUKS_PASSPHRASE" |
        cryptsetup luksFormat \
            --batch-mode \
            --type luks2 \
            --key-file=- \
            "$PART_ROOT"

    printf '%s' "$LUKS_PASSPHRASE" |
        cryptsetup open \
            --key-file=- \
            "$PART_ROOT" \
            "$MAPPER_NAME"

    MAPPER_OPEN=1

    ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")

    [[ -n "$ROOT_UUID" ]] || \
        die "Could not retrieve LUKS UUID."

    ok "LUKS2 encryption configured."
}

# ------------------------------------------------------------
# 12. FILESYSTEMS
# ------------------------------------------------------------

format_filesystems() {
    info "Formatting EFI partition..."

    mkfs.fat -F32 "$PART_BOOT"

    info "Formatting encrypted root..."

    mkfs.ext4 -F "/dev/mapper/$MAPPER_NAME"

    ok "Filesystems created."
}

# ------------------------------------------------------------
# 13. MOUNTING
# ------------------------------------------------------------

mount_filesystems() {
    info "Mounting filesystems..."

    mount "/dev/mapper/$MAPPER_NAME" /mnt
    MOUNTED=1

    mkdir -p /mnt/boot

    mount "$PART_BOOT" /mnt/boot

    ok "Filesystems mounted."
}

# ------------------------------------------------------------
# 14. MICROCODE DETECTION
# ------------------------------------------------------------

detect_microcode() {
    local vendor

    vendor=$(awk -F: '
        /vendor_id/ {
            gsub(/[[:space:]]/, "", $2)
            print $2
            exit
        }
    ' /proc/cpuinfo)

    case "$vendor" in
        GenuineIntel)
            echo "intel-ucode"
            ;;
        AuthenticAMD)
            echo "amd-ucode"
            ;;
        *)
            warn "Unknown CPU vendor: $vendor"
            echo ""
            ;;
    esac
}

# ------------------------------------------------------------
# 15. BASE INSTALLATION
# ------------------------------------------------------------

install_base() {
    info "Bootstrapping Arch Linux..."

    local microcode
    microcode=$(detect_microcode)

    local packages=(
        base
        linux
        linux-firmware
        cryptsetup
        sudo
        nano
        base-devel
        smartmontools
    )

    [[ -n "$microcode" ]] && packages+=("$microcode")

    pacstrap -K /mnt "${packages[@]}"

    ok "Base system installed."
}

# ------------------------------------------------------------
# 16. FSTAB
# ------------------------------------------------------------

generate_fstab() {
    info "Generating fstab..."

    genfstab -U /mnt > /mnt/etc/fstab

    grep -q '/boot' /mnt/etc/fstab || \
        die "EFI mount entry missing from fstab."

    grep -q 'cryptroot' /mnt/etc/fstab || \
        die "Encrypted root mount entry missing from fstab."

    ok "fstab generated."
}

# ------------------------------------------------------------
# 17. SYSTEM CONFIGURATION
# ------------------------------------------------------------

configure_system() {
    info "Configuring installed system..."

    arch-chroot /mnt \
        /usr/bin/env \
        TARGET_HOSTNAME="$HOSTNAME" \
        TARGET_TIMEZONE="$TIMEZONE" \
        TARGET_LOCALE="$LOCALE" \
        TARGET_USER="$USER_NAME" \
        TARGET_UUID="$ROOT_UUID" \
        TARGET_MAPPER="$MAPPER_NAME" \
        /bin/bash -s <<'CHROOT'

set -Eeuo pipefail

# Timezone
ln -sf "/usr/share/zoneinfo/$TARGET_TIMEZONE" /etc/localtime
hwclock --systohc

# Locale
if ! grep -qxF "$TARGET_LOCALE UTF-8" /etc/locale.gen; then
    echo "$TARGET_LOCALE UTF-8" >> /etc/locale.gen
fi

locale-gen

echo "LANG=$TARGET_LOCALE" > /etc/locale.conf

# Hostname
echo "$TARGET_HOSTNAME" > /etc/hostname

# Hosts file
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME
EOF

# User creation
useradd -m -G wheel -s /bin/bash "$TARGET_USER"

# Sudo configuration
cat > /etc/sudoers.d/10-wheel <<'SUDO'
%wheel ALL=(ALL:ALL) ALL
bhava ALL=(root) NOPASSWD: /usr/bin/smartctl
SUDO

chmod 0440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers

# Networking
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

cat > /etc/systemd/network/20-wired.network <<'NETWORK'
[Match]
Name=en* eth*

[Network]
DHCP=yes
NETWORK

# Maintenance services
systemctl enable fstrim.timer

# Pacman configuration
sed -i \
    's/^#ParallelDownloads = 5/ParallelDownloads = 5/' \
    /etc/pacman.conf

# Build configuration
JOBS=$(nproc)

if grep -q '^#MAKEFLAGS=' /etc/makepkg.conf; then
    sed -i \
        "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j${JOBS}\"/" \
        /etc/makepkg.conf
elif ! grep -q '^MAKEFLAGS=' /etc/makepkg.conf; then
    echo "MAKEFLAGS=\"-j${JOBS}\"" >> /etc/makepkg.conf
fi

# Disable debug packages
if grep -q '^OPTIONS=' /etc/makepkg.conf; then
    sed -i '/^OPTIONS=/s/ debug / !debug /' /etc/makepkg.conf
fi

# Initramfs configuration
sed -i -E \
    's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
    /etc/mkinitcpio.conf

# Generate initramfs
mkinitcpio -P

# Install systemd-boot
mkdir -p /boot/loader/entries

bootctl --esp-path=/boot install

# Bootloader configuration
cat > /boot/loader/loader.conf <<'LOADER'
default arch.conf
timeout 3
console-mode max
editor no
LOADER

# Arch boot entry
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=$TARGET_UUID=$TARGET_MAPPER root=/dev/mapper/$TARGET_MAPPER rw quiet
EOF

# Validate generated files
test -s /boot/vmlinuz-linux
test -s /boot/initramfs-linux.img
test -s /boot/loader/entries/arch.conf

sync

CHROOT

    ok "System configuration completed."
}

# ------------------------------------------------------------
# 18. SET ACCOUNT PASSWORDS
# ------------------------------------------------------------

configure_passwords() {
    info "Setting account passwords..."

    printf '%s:%s\n' root "$ROOT_PASSWORD" |
        arch-chroot /mnt chpasswd

    printf '%s:%s\n' "$USER_NAME" "$USER_PASSWORD" |
        arch-chroot /mnt chpasswd

    unset ROOT_PASSWORD USER_PASSWORD

    ok "Account passwords configured."
}

# ------------------------------------------------------------
# 19. FINAL VERIFICATION
# ------------------------------------------------------------

verify_installation() {
    info "Performing final verification..."

    local required_files=(
        /mnt/etc/fstab
        /mnt/etc/hostname
        /mnt/etc/locale.conf
        /mnt/etc/mkinitcpio.conf
        /mnt/etc/shadow
        /mnt/boot/vmlinuz-linux
        /mnt/boot/initramfs-linux.img
        /mnt/boot/loader/loader.conf
        /mnt/boot/loader/entries/arch.conf
    )

    local file

    for file in "${required_files[@]}"; do
        [[ -s "$file" ]] || die "Missing or empty file: $file"
    done

    arch-chroot /mnt passwd -S root
    arch-chroot /mnt passwd -S "$USER_NAME"

    cryptsetup status "$MAPPER_NAME"

    ok "Final verification passed."
}

# ------------------------------------------------------------
# 20. MAIN
# ------------------------------------------------------------

main() {
    echo
    echo "============================================================"
    echo "              ARCH LINUX INSTALLER"
    echo "============================================================"

    check_root
    check_uefi
    check_commands
    check_timezone

    select_disk
    check_disk_safety

    collect_user_details
    confirmation

    configure_clock

    partition_disk
    configure_encryption
    format_filesystems
    mount_filesystems

    install_base
    generate_fstab

    configure_system
    configure_passwords

    verify_installation

    sync

    unset LUKS_PASSPHRASE

    echo
    ok "ARCH LINUX INSTALLATION COMPLETED SUCCESSFULLY."
    info "Review installation log: $LOG_FILE"
    info "Unmounting and closing encrypted root."

    echo
    info "Reboot when ready. Remove the installation media."
}

main "$@"
