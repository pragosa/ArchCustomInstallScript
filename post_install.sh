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

if ask_yes "==> Install Desktop environment: "; then
    sudo pacman -S --needed "${DESKTOP[@]}" "${APPS[@]}"
    systemctl --user enable hyprpolkitagent
fi

case ${HOSTNAME} in
    # laptop
    arsene)
        echo "${BLUE}==> Installing hardware specific pkgs (${HOSTNAME})${RESET}"
        sudo pacman -S --needed "${HARDWARE_PKGS_LAPTOP[@]}"
        sudo systemctl enable --now bluetooth
    ;;

    # server
    orpheus)
        echo "${BLUE}==> Installing hardware specific pkgs (${HOSTNAME})${RESET}"
        sudo pacman -S --needed "${HARDWARE_PKGS_SERVER[@]}"
    ;;

    # dafault behavior
    *)
        echo "${YELLOW}No hardware specific pkgs for ${HOSTNAME}${RESET}"
    ;;
esac

# Make xdg default folders
xdg-user-dirs-update

# Enable ssh-agent
echo "Enabling ssh-agent service (requires logout)"
sudo systemctl --global enable ssh-agent

# Enable tlp service (power management) (see arch wiki tlp - rfkill?)
if pacman -Qeq tlp > /dev/null 2>&1; then 
    sudo systemctl enable --now tlp.service
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
fi


echo "${BLUE}Creating SSH key ...${RESET}"
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
      ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
  fi
