#!/usr/bin/env bash
# -----------------------------------------------------------
# Post install: run after the first boot, as your normal user.
#   ./post_install.sh
# -----------------------------------------------------------
 
set -euo pipefail
 
cd "$(dirname "$0")"
source src/configuration.sh
source src/helper_functions.sh

source pkgs/base_pkgs.conf
source pkgs/packages.conf

# PKGS GROUPS -- common
ALL_PKGS=(
    # From base_pkgs.conf
    "${BASE_PACKAGES[@]}"
    "${HARDWARE_PKGS_COMMON[@]}"

    # From packages.conf
    "${DEFAULT_PKGS[@]}"
    "${LSPS[@]}"
    "${GRAPHICAL[@]}"
    "${FONTS[@]}"
    "${SYSTEM_AUDIO[@]}"

    # Temporary pkgs
    "${TEMP_PKGS[@]}"
)

[[ $EUID -ne 0 ]] || die "Run as your normal user (the script uses sudo when needed)"

verify_internet

echo "${BLUE}==> Updating the system${RESET}"
sudo pacman -Syu

echo "${BLUE}==> Installing packages${RESET}"
sudo pacman -S --needed "${ALL_PKGS[@]}"
sudo pacman -D --asexplicit "${ALL_PKGS[@]}"

if ask_yes "==> Install Desktop environment: "; then
    sudo pacman -S --needed "${DESKTOP[@]}" "${APPS[@]}"
    sudo pacman -D --asexplicit "${DESKTOP[@]}" "${APPS[@]}"
    systemctl --user enable hyprpolkitagent
fi


# Hardware specific configs/pkgs
case ${HOSTNAME} in
    # laptop
    arsene)
        echo "${BLUE}==> Installing hardware specific pkgs (${HOSTNAME})${RESET}"
        sudo pacman -S --needed "${HARDWARE_PKGS_LAPTOP[@]}"
        sudo pacman -D --asexplicit "${HARDWARE_PKGS_LAPTOP[@]}" 
        sudo systemctl enable --now bluetooth acpid
        sudo install -Dm644 configs/80-laptopgpus.rules /etc/udev/rules.d/80-laptopgpus.rules
    ;;

    # server
    orpheus)
        echo "${BLUE}==> Installing hardware specific pkgs (${HOSTNAME})${RESET}"
        sudo pacman -S --needed "${HARDWARE_PKGS_SERVER[@]}"
        sudo pacman -D --asexplicit "${HARDWARE_PKGS_SERVER[@]}" 
    ;;

    # dafault behavior
    *)
        echo "${YELLOW}No hardware specific pkgs for ${HOSTNAME}${RESET}"
    ;;
esac

# Make xdg default folders
xdg-user-dirs-update

# Font config system-wide
echo "Font config system ..."
sudo install -Dm644 configs/52-defaultfonts.conf /etc/fonts/conf.d/52-defaultfonts.conf

# Enable ssh-agent
echo "Enabling ssh-agent service (requires logout)"
sudo systemctl --global enable ssh-agent
sudo install -Dm644 configs/ssh-agent.sh /etc/profile.d/ssh-agent.sh
sudo install -Dm644 configs/10-ssh-client.conf /etc/ssh/ssh_config.d/10-ssh-client.conf

# Enable tlp service (power management) (see arch wiki tlp - rfkill?)
if pacman -Qeq tlp > /dev/null 2>&1; then 
    sudo systemctl enable --now tlp.service
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
fi


if [[ ! -f ~/.ssh/id_ed25519 ]]; then
    echo "${BLUE}Creating SSH key ...${RESET}"
    install -d -m 700 ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
fi

# tailscale
echo "Enabling tailscale service"
sudo systemctl enable --now tailscaled

# Snapshot current packages
echo "${YELLOW}Snapshotting package list ...${RESET}"
pacman -Qeq > "${HOME}/.packagelistsnapshot"


echo "Done! (reboot to apply some configurations)"
