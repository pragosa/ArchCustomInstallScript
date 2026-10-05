#!/usr/bin/env bash
# -----------------------------------------------------------
# Script to install arch linux in my way
# Includes:
#       -> boot only for GPT (efi)
#       -> main is encrypted with luks
# -----------------------------------------------------------
# WARNING: THIS SCRIPT DELETES EVERYTHING IN THE DRIVE.
# -----------------------------------------------------------

set -euo pipefail

cd "$(dirname "$0")"
source src/configuration.sh
source src/helper_functions.sh
source pkgs/base_pkgs.conf

if ! ask_yes "Did you verify the configuration variables?"; then
    die "Edit configuration.sh first."
fi

# Get hostname
NAME_HOST=${1:-}
[[ -n $NAME_HOST ]] || die "uso: $0 <hostname>   (ex.: $0 mypcHostname)"

# 1. Verify internet connectivity
verify_internet

# For interactive 
loadkeys "$KEYMAP"

# 2. Define correct drive.
parted_script


# 3. encrypt with luks main partition
ENCRYPT_FLAG=no
if ask_yes "Encrypt disk (LUKS2)?"; then 
    ENCRYPT_FLAG=yes
fi
encrypt_disk_script


# 4. make file systems
mkfs.fat -F32 -n BOOT "$PART_BOOT"
mkfs.ext4 -L main "$ROOT_DEV"


# 5. mount
mount "$ROOT_DEV" /mnt
mount --mkdir -o fmask=0137,dmask=0027 "$PART_BOOT" /mnt/boot


# 6. install essential packages
check_ucode
reflector --latest 20 --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt "${BASE_PACKAGES[@]}" "$UCODE_PKG"


# 7. fstab and swap
echo "generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab

mkswap --file /mnt/swapfile --size ${SWAPFILE_SIZE}
echo '/swapfile none swap defaults 0 0' >> /mnt/etc/fstab

cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram * 0.3
compression-algorithm = zstd
swap-priority = 100
EOF

# 8. prep work
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime

for loc in "${LOCALES[@]}"; do
    sed -i "s/^#$loc/$loc/" /mnt/etc/locale.gen
done

echo "LANG=$LANG_DEFAULT" > /mnt/etc/locale.conf
for v in "${LC_VARS[@]}"; do
    echo "$v=$LC_LOCALE" >> /mnt/etc/locale.conf
done

echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$NAME_HOST" > /mnt/etc/hostname

cat >> /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $NAME_HOST.localdomain $NAME_HOST
EOF

sed -i "s/^HOOKS=.*/HOOKS=($HOOKS)/" /mnt/etc/mkinitcpio.conf
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
chmod 440 /mnt/etc/sudoers.d/wheel

# only for laptop
if [[ $NAME_HOST == arsene ]]; then
    arch-chroot /mnt hwclock --systohc --localtime
else
    arch-chroot /mnt hwclock --systohc
fi


# 9. chroot
arch-chroot /mnt /bin/bash -e <<EOF
locale-gen
mkinitcpio -P
bootctl install
useradd -m -G "$USER_GROUPS" -s "$USER_SHELL" "$USERNAME_NAME"

ufw default deny incoming
ufw default allow outgoing
sed -i 's/^ENABLED=no/ENABLED=yes/' /etc/ufw/ufw.conf

systemctl enable NetworkManager sshd ufw
EOF

# 10. User and root password
echo "Root Password:"
until arch-chroot /mnt passwd; do echo "Try again."; done

echo "$USERNAME_NAME Password:"
until arch-chroot /mnt passwd "$USERNAME_NAME"; do echo "Try again."; done

# 11. Bootloader
__ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")
if [[ $ENCRYPT_FLAG == yes ]]; then
    __OPTS_ROOT="cryptdevice=UUID=$__ROOT_UUID:cryptroot root=/dev/mapper/cryptroot rw zswap.enabled=0"
else
    __OPTS_ROOT="root=UUID=$__ROOT_UUID rw zswap.enabled=0"
fi

# entries and loader files
cat > /mnt/boot/loader/loader.conf <<EOF
default arch.conf
timeout 0
console-mode auto
editor no
EOF

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options $__OPTS_ROOT
EOF

cat > /mnt/boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options $__OPTS_ROOT
EOF


# openssh config
mkdir -p /mnt/etc/ssh/sshd_config.d
cat > /mnt/etc/ssh/sshd_config.d/10-primary.conf <<EOF
Port $PORT_SSHCONFIG
AllowUsers $USERNAME_NAME
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no

# WARN: This should be temporary
PasswordAuthentication yes
EOF


# closing
umount -R /mnt
if [[ $ENCRYPT_FLAG == yes ]]; then
    cryptsetup close cryptroot;
fi

echo -e "${BLUE}===========================================\nCompleted!!!\n\n${RESET}"
