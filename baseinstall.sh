#!/usr/bin/env bash
set -euo pipefail

if [[ ${UID} -ne 0 ]]; then
    echo "This script needs to be run as root." >&2
    exit 3
fi

timedatectl set-ntp true

locale="en_CA.UTF-8"
timezone="America/Vancouver"
red=$'\e[1;31m'
rst=$'\e[0m'
msg() { printf '%s%s%s\n' "${red}" "$*" "${rst}"; }

lsblk -d -o NAME,SIZE,MODEL,TRAN
read -r -p "${red}Install to which disk? (e.g. nvme0n1, sda): ${rst}" target
target=${target#/dev/}
disk=/dev/${target}

[[ -b ${disk} ]] || { echo "Not a block device: ${disk}" >&2; exit 1; }

read -r -p "${red}This will ERASE partitions 1 and 2 on ${disk}. Type the disk name to continue: ${rst}" confirm
[[ ${confirm} == "${target}" ]] || { echo "Aborted."; exit 1; }

read -r -p "${red}Hostname [${hostname:-$(date +%Y%b)}]: ${rst}" hostname
hostname=${hostname:-$(date +%Y%b)}
read -r -p "${red}Username: ${rst}" username
[[ ${username} =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid username." >&2; exit 1; }

# Delete only the first two partitions instead of a full disk zap
sgdisk -d 1 -d 2 "${disk}" || true
sgdisk \
    -n1:0:+1G  -t1:ef00 -c1:boot \
    -n2:0:+50G -t2:8304 -c2:linux \
    "${disk}"

partprobe "${disk}"
udevadm settle --timeout=10
until [[ -e /dev/disk/by-partlabel/linux && -e /dev/disk/by-partlabel/boot ]]; do
    sleep 0.2
done

msg "Encrypting root..."
cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/disk/by-partlabel/linux
cryptsetup open /dev/disk/by-partlabel/linux root

mkfs.fat -F32 -n EFISYSTEM /dev/disk/by-partlabel/boot
mkfs.ext4 -F -L linux /dev/mapper/root

mount /dev/mapper/root /mnt
install -d /mnt/boot
mount /dev/disk/by-partlabel/boot /mnt/boot

msg "Pacstrapping..."
pacstrap_pkgs=(base base-devel linux linux-firmware nano cryptsetup intel-ucode git sudo polkit-gnome firefox sway kitty xdg-desktop-portal-wlr nvme-cli smartmontools efibootmgr)

pacstrap -K /mnt "${pacstrap_pkgs[@]}"

genfstab -U /mnt >> /mnt/etc/fstab
sed -i 's/relatime/noatime/' /mnt/etc/fstab

luks_uuid=$(blkid -s UUID -o value /dev/disk/by-partlabel/linux)

msg "Entering Chroot configuration..."
arch-chroot /mnt /usr/bin/bash <<EOF
set -euo pipefail

echo "${hostname}" > /etc/hostname
ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc --utc

sed -i -e "/^#${locale}/s/^#//" /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "${locale}" > /etc/locale.conf
printf 'KEYMAP=us\n' > /etc/vconsole.conf

printf '%s\n' \
    '127.0.0.1 localhost' \
    '::1        localhost' \
    "127.0.1.1 ${hostname}.localdomain ${hostname}" > /etc/hosts

useradd -mG wheel "${username}"

echo "Setting password for user: ${username}"
passwd "${username}"
echo "Setting password for root:"
passwd root

install -d -m 750 /etc/sudoers.d

cat << 'SUDOWHEEL' > /etc/sudoers.d/wheel
%wheel ALL=(ALL:ALL) ALL
SUDOWHEEL

cat << SUDOHW > /etc/sudoers.d/hwtools
${username} ALL=(ALL:ALL) NOPASSWD: /usr/bin/nvme
${username} ALL=(ALL:ALL) NOPASSWD: /usr/bin/smartctl
SUDOHW

chown root:root /etc/sudoers.d/hwtools /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/hwtools

if ! visudo -c; then
    echo "ERROR: Sudoers configuration validation failed!" >&2
    exit 1
fi

# Optimized Hooks: Standardized layout ordering for clean systemd decryption
sed -i 's/^HOOKS=.*/HOOKS=(base systemd keyboard autodetect microcode modconf kms sd-vconsole block sd-encrypt filesystems fsck)/' \
    /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable systemd-resolved systemd-networkd
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

cat > /etc/systemd/network/20-wired.network << 'NETEOF'
[Match]
Type=ether

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes
NETEOF

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/^#Color/s/^#//" /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

sed -i 's/-march=[^ ]* -mtune=[^ ]*/-march=native/' /etc/makepkg.conf
# Corrected escaping: Resolves the multi-threaded compilation variable generation mapping
sed -i 's|^#\?MAKEFLAGS=.*|MAKEFLAGS="-j$(nproc)"|' /etc/makepkg.conf
sed -i 's/\bdebug\b/!debug/g' /etc/makepkg.conf

sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf

if [ -f /etc/makepkg.conf.d/rust.conf ]; then
    sed -i 's/^RUSTFLAGS=.*/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' /etc/makepkg.conf.d/rust.conf
else
    sed -i 's/^RUSTFLAGS=.*/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' /etc/makepkg.conf
fi

bootctl install
cat > /boot/loader/loader.conf << 'LOADEOF'
default arch.conf
timeout 3
editor no
LOADEOF

cat << ENTRYEOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd /intel-ucode.img
initrd  /initramfs-linux.img
options rd.luks.name=${luks_uuid}=root root=/dev/mapper/root rw quiet loglevel=3 ibt=off
ENTRYEOF

install -d -o "${username}" -g "${username}" "/home/${username}/.dotfiles"
EOF

msg "Unmounting and wrapping up..."
umount -R /mnt
cryptsetup close root
echo "==> Installation complete. Reboot."
