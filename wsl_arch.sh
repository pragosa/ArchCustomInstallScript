#!/usr/bin/env bash
# -----------------------------------------------------------
# Script to install arch linux in wsl
# -----------------------------------------------------------

set -euo pipefail

cd "$(dirname "$0")"
source src/configuration.sh
source src/helper_functions.sh
source pkgs/base_pkgs.conf

if ! ask_yes "Did you verify the configuration variables? (username: ${USERNAME_NAME})"; then
    die "Edit configuration.sh first."
fi

# update pkgs
pacman -Syu
pacman -S "${BASE_PACKAGES[@]}" "${DEFAULT_PKGS[@]}" "${LSPS[@]}" "${GRAPHICAL[@]}" "${FONTS[@]}" "${SYSTEM_AUDIO[@]}" "${TEMP_PKGS[@]}"
reflector --latest 20 --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist

# Override wsl locale
ln -sf /etc/locale.conf /etc/default/locale
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

# locale change
for loc in "${LOCALES[@]}"; do
    sed -i "s/^#$loc/$loc/" /etc/locale.gen
done

echo "LANG=$LANG_DEFAULT" > /etc/locale.conf
for v in "${LC_VARS[@]}"; do
    echo "$v=$LC_LOCALE" >> /etc/locale.conf
done

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

locale-gen

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Create user
useradd -m -G "$USER_GROUPS" -s "$USER_SHELL" "$USERNAME_NAME"

# User and root password
echo "Root Password:"
until arch-chroot /mnt passwd; do echo "Try again."; done

echo "$USERNAME_NAME Password:"
until arch-chroot /mnt passwd "$USERNAME_NAME"; do echo "Try again."; done

# Wsl default user
cat > /etc/wsl.conf <<EOF
[user]
default = $USERNAME_NAME
EOF

# openssh config
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-primary.conf <<EOF
Port $PORT_SSHCONFIG
AllowUsers $USERNAME_NAME
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no

# WARN: This should be temporary
PasswordAuthentication yes
EOF

echo -e "${BLUE}===========================================\nCompleted!!!\n\n${RESET}"
