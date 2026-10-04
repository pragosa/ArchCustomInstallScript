#!/usr/bin/env bash
# -----------------------------------------------------------
# Post install: run after the first boot, as your normal user.
#   ./post_install.sh
# -----------------------------------------------------------
 
set -euo pipefail
 
cd "$(dirname "$0")"
source configuration.sh
source helper_functions.sh

source pkgs/base_pkgs.conf
source pkgs/packages.conf

# PKGS GROUPS -- common
ALL_PKGS=(
    "${BASE_PACKAGES[@]}"
    "${HARDWARE_PKGS_COMMON[@]}"
    "${DEFAULT_PKGS[@]}"
    "${LSPS[@]}"
    "${GRAPHICAL[@]}"
    "${TEMP_PKGS[@]}"
    "${FONTS[@]}"
)

[[ $EUID -ne 0 ]] || die "Run as your normal user (the script uses sudo when needed)"

verify_internet

echo "${BLUE}==> Updating the system${RESET}"
sudo pacman -Syu

echo "${BLUE}==> Installing packages${RESET}"
sudo pacman -S --needed "${ALL_PKGS[@]}"

