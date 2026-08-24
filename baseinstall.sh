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

cpu_vendor=$(awk -F: '/^vendor_id/{print $2; exit}' /proc/cpuinfo)
case ${cpu_vendor} in
    *GenuineIntel*) ucode_pkg=intel-ucode ;;
    *AuthenticAMD*) ucode_pkg=amd-ucode ;;
    *) ucode_pkg= ;;
esac

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
pacstrap -K /mnt base base-devel linux linux-firmware ${ucode_pkg} \
    nano cryptsetup git sudo polkit \
    firefox sway foot xdg-desktop-portal-wlr \
    nvme-cli smartmontools pigz pbzip2 efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab
sed -i 's/relatime/noatime/' /mnt/etc/fstab

luks_uuid=$(blkid -s UUID -o value /dev/disk/by-partlabel/linux)

arch-chroot /mnt /bin/bash -s -- "${hostname}" "${locale}" "${timezone}" "${username}" "${luks_uuid}" <<'CHROOT'
set -euo pipefail
hostname=$1 
locale=$2 
timezone=$3 
username=$4 
luks_uuid=$5

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
echo "Password for ${username}:"
passwd "${username}"
echo "Password for root:"
passwd root

install -d -m 750 /etc/sudoers.d
tee /etc/sudoers.d/wheel <<'EOF' >/dev/null
%wheel ALL=(ALL:ALL) ALL
EOF

tee /etc/sudoers.d/hwtools <<EOF >/dev/null
${username} ALL=(ALL:ALL) NOPASSWD: /usr/bin/nvme
${username} ALL=(ALL:ALL) NOPASSWD: /usr/bin/smartctl
EOF

chmod 440 /etc/sudoers.d/wheel /etc/sudoers.d/hwtools
if ! visudo -c; then
    echo "ERROR: Sudoers configuration validation failed!" >&2
    exit 1
fi

sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
    /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable systemd-resolved systemd-networkd

cat > /etc/systemd/network/20-wired.network <<'EOF'
[Match]
Type=ether

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes
EOF

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/^#Color/s/^#//" /etc/pacman.conf
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

sed -i 's/-march=[^ ]* -mtune=[^ ]*/-march=native/' /etc/makepkg.conf
sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j\$(nproc)\"/" /etc/makepkg.conf
sed -i 's/\bdebug\b/!debug/g' /etc/makepkg.conf

sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf
sed -i 's/^COMPRESSGZ=.*/COMPRESSGZ=(pigz -c -f -n)/' /etc/makepkg.conf
sed -i 's/^COMPRESSBZ2=.*/COMPRESSBZ2=(pbzip2 -c -f)/' /etc/makepkg.conf
sed -i 's/^COMPRESSZST=.*/COMPRESSZST=(zstd -c -T0 -)/' /etc/makepkg.conf

if [ -f /etc/makepkg.conf.d/rust.conf ]; then
    sed -i 's/^RUSTFLAGS=.*/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' /etc/makepkg.conf.d/rust.conf
else
    sed -i 's/^RUSTFLAGS=.*/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' /etc/makepkg.conf
fi

bootctl install
cat > /boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 3
editor no
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${luks_uuid}=root root=/dev/mapper/root rw quiet loglevel=3 ibt=off
EOF

install -d -o "${username}" -g "${username}" "/home/${username}/.dotfiles"
CHROOT

umount -R /mnt
cryptsetup close root
echo "==> Installation complete. Reboot."
