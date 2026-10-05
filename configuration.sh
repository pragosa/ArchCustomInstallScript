#!/usr/bin/env bash

# TODO: Verify variables
USERNAME_NAME="PUT USERNAME HERE"

TIMEZONE="Europe/Lisbon"

KEYMAP="pt-latin1"

LANG_DEFAULT="en_US.UTF-8"
LC_LOCALE="pt_PT.UTF-8"
LOCALES=("$LANG_DEFAULT" "$LC_LOCALE")

USER_GROUPS="wheel,video,render"
USER_SHELL="/usr/bin/zsh"       # or /usr/bin/bash

SWAPFILE_SIZE=16G

PORT_SSHCONFIG=15222

HOOKS_BASE="base udev autodetect microcode modconf kms keyboard keymap consolefont block"

# For later, dont change
LC_VARS=(LC_ADDRESS LC_IDENTIFICATION LC_MEASUREMENT LC_MONETARY LC_NAME
         LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME)
