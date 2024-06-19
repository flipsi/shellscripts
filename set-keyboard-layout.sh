#!/usr/bin/env bash

# Author: "Philipp Moers" <soziflip@gmail.com>

set -e


# TODO: Automatically execute this script and document
# https://unix.stackexchange.com/a/65892/119362
# https://linuxconfig.org/tutorial-on-how-to-write-basic-udev-rules-in-linux
# > cat /etc/udev/rules.d/120-moonlander-keyboard-layout.rules
# ATTRS{idVendor}=="3297", ATTRS{idProduct}=="1969", RUN+="/home/sflip/shellscripts/set-keyboard-layout.sh"
# TODO: have to set DISPLAY?


function _print_help_msg() {
    cat <<-EOF
Set keyboard layout according on my use cases.

Usage: $(basename "$0") [ --help | LAYOUT ]

EOF
}

function in_X() {
    test -n "$DISPLAY"
}

function is_zsa_keyboard_connected() {
    find "/dev/input/by-id" -name 'usb-ZSA_Technology_Labs_*' 2>/dev/null | grep -q .
}

function determine_layout() {
    if is_zsa_keyboard_connected; then
        echo 'de -variant nodeadkeys'
    else
        echo 'us_norman_sflip'
    fi
}

function main() {
    if [[ -z "$1" ]]; then
        LAYOUT=$(determine_layout)
    else
        LAYOUT=$@
    fi
    if in_X; then
        setxkbmap $LAYOUT
    else
        loadkeys "$1"
    fi
}


if [[ "$1" = "--help" ]]; then
    _print_help_msg
else
    main $@
fi


