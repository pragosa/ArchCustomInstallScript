#!/usr/bin/env bash
# -----------------------------------------------------------
# Post install: run after the first boot, as your normal user.
#   ./post_install.sh
# -----------------------------------------------------------
 
set -euo pipefail
 
cd "$(dirname "$0")"
source configuration.sh
source helper_functions.sh
source packages.conf

[[ $EUID -ne 0 ]] || die "Run as your normal user (the script uses sudo when needed)"

ask_yes "Did you verify the configuration variables?" || die "Edit configuration.sh first"

verify_internet

echo "${BLUE}==> Updating the system${RESET}"
sudo pacman -Syu

echo "${BLUE}==> Installing packages${RESET}"
sudo pacman -S --needed \
    "${SYSTEM_BASE[@]}" "${SYSTEM_AUDIO[@]}" "${SYSTEM_UTILS[@]}" \
    "${DEV_TOOLS[@]}" "${LSPS[@]}" "${GRAPHICAL[@]}" "${DESKTOP[@]}" \
    "${TEMP[@]}" "${APPS[@]}" "${FONTS[@]}"

