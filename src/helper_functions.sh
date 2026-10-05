#!/usr/bin/env bash


# color codes
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
BOLD=$'\e[1m'
RESET=$'\e[0m'


# error handling
die() { echo "${RED}ERROR: $*${RESET}"; exit 1; }


ask_yes() {
    local r
    read -rp "$1 [s/N]: " r
    [[ $r == [sS]* ]]
}


# verify internet acess
# send 1 packet and wait 3 seconds max
verify_internet() {
    ping -c 1 -W 3 archlinux.org > /dev/null 2>&1 \
    || die "No internet acess. (iwctl for wifi)";

    echo "Connected to the internet!"
}


# check disks
parted_script() {
    lsblk
    read -rp "Choose drive (eg.: /dev/sdb): " DISCO

    # test to see if disco is a block device
    if [ ! -b "$DISCO" ]; then
        die "$DISCO is not a block device."
    fi

    # nvme and mmc drives use a "p" before the partition number (nvme0n1p1)
    if [[ "$DISCO" == *nvme* || "$DISCO" == *mmcblk* ]]; then
        P="${DISCO}p"
    else
        P="$DISCO"
    fi


    PART_BOOT="${P}1"      # boot part
    PART_ROOT="${P}2"      # root part main
    echo -e "BOOT: $PART_BOOT\nROOT: $PART_ROOT"
    echo "================================================="

     # confirm BEFORE erasing anything
    echo "WARNING: everything on $DISCO will be erased!"
    read -rp "Type \"yes\" to continue: " RESP
    [ "$RESP" = "yes" ] || die "Cancelled, nothing was changed"


    # 3. make partitions
    # Layout:
    #  - 1GB EFI/boot
    #  - remaining is for root
    parted -s "$DISCO" mklabel gpt

    # esp/boot
    parted -s "$DISCO" mkpart ESP fat32 1MiB 1GiB
    parted -s "$DISCO" set 1 esp on

    # primary
    parted -s "$DISCO" mkpart primary ext4 1GiB 100%

    echo "Partitions created."
    echo "Verify them!"
    lsblk
    echo "----------------"
    sleep 2s
}

encrypt_disk_script() {
    if [[ $ENCRYPT_FLAG == yes ]]; then
        echo "Write YES (in capital letters)"
        until cryptsetup luksFormat --type luks2 "$PART_ROOT"; do
            echo "Failed, try again!"
        done
        cryptsetup open "$PART_ROOT" cryptroot
        ROOT_DEV=/dev/mapper/cryptroot
        HOOKS="$HOOKS_BASE encrypt filesystems fsck"
    else
        ROOT_DEV=$PART_ROOT
        HOOKS="$HOOKS_BASE filesystems fsck"
    fi
}

check_ucode() {
    if grep AuthenticAMD /proc/cpuinfo; then
        UCODE_PKG=amd-ucode
    else
        UCODE_PKG=intel-ucode
    fi
}
