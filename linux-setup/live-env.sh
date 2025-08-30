#!/bin/bash

# Helper to conveniently use a Linux live environment and automate recurring setup commands.
# Note that this script is not generic and very specific to my personal needs and convention.

# Usage:
#     wget -q -O - "$SELF_URL" | bash -i

# SELF_URL='https://github.com/flipsi/shellscripts/tree/master/linux-setup/live-env.sh'
SELF_URL='https://raw.githubusercontent.com/flipsi/shellscripts/master/linux-setup/live-env.sh'

BASHRC_URL='https://raw.githubusercontent.com/flipsi/dotfiles/master/bash/bashrc_sflip'

KEYBOARD_LAYOUT='us -variant norman'
EXTERNAL_SCREEN_ROTATION='left'

EFI_PARTITION='/dev/nvme0n1p1'
# BOOT_PARTITION='/dev/nvme0n1p2'
BOOT_PARTITION='/dev/nvme0n1p4'
LUKS_PARTITION='/dev/nvme0n1p3'
LUKS_VOLUME='luks_root'
LUKS_GROUP='supergroup'
ROOT_PARTITION='/dev/$LUKS_GROUP/fedora-root'
HOME_PARTITION='/dev/$LUKS_GROUP/home'


function download_self() {
    wget "$SELF_URL"
}

function has() {
    type "$1" > /dev/null 2>&1
}


function in_X() {
    test -n "$DISPLAY"
}

function is_zsa_keyboard_connected() {
    find "/dev/input/by-id" -name 'usb-ZSA_Technology_Labs_*' 2>/dev/null | grep -q .
}

function determine_keyboard_layout() {
    if is_zsa_keyboard_connected; then
        echo 'de -variant nodeadkeys'
    else
        echo "$KEYBOARD_LAYOUT"
    fi
}

function set_keyboard_layout() {
    if [[ -z "$1" ]]; then
        LAYOUT=$(determine_keyboard_layout)
    else
        LAYOUT=$@
    fi
    if in_X; then
        setxkbmap $LAYOUT
    else
        loadkeys "$1"
    fi
}

function get_laptop_screen() {
    xrandr | grep -E 'eDP-?.? connected' | head -n1 | cut -d ' ' -f1
}

function get_external_screen() { # (assuming there is only one)
    xrandr | grep ' connected' | grep -v -E 'eDP-?.? connected' | head -n1 | cut -d ' ' -f1
}

function use_external_screen_if_available() {
    EXTERNAL_SCREEN="$(get_external_screen)"
    LAPTOP_SCREEN="$(get_laptop_screen)"
    if [[ -n "$EXTERNAL_SCREEN" ]] ; then
	xrandr \
	    --output "$LAPTOP_SCREEN" --off \
	    --output "$EXTERNAL_SCREEN" --primary --auto --rotate "$EXTERNAL_SCREEN_ROTATION"
    fi
}

function mount_partitions() {
    lsblk --fs
    if sudo cryptsetup status "$LUKS_VOLUME" | grep 'inactive'; then
	# TODO: fix interactive password prompt (bash -i above seems not to be enough, this terminates with 'Nothing to read on input'
	sudo cryptsetup open "$LUKS_PARTITION" "$LUKS_VOLUME"
    fi
    sudo mount "$ROOT_PARTITION" /mnt
    sudo mount "$BOOT_PARTITION" /mnt/boot
    sudo mount "$EFI_PARTITION" /mnt/boot/efi
    sudo mount "$HOME_PARTITION" /mnt/home
    for d in dev proc run sys; do
	sudo mount -o bind "/$d" "/mnt/$d"
    done
    lsblk --fs
}

function reinstall_grub() {
    SYSTEM_CONFIG_FILE="/etc/default/grub"
    # GRUB_CONFIG_FILE="/boot/grub/grub.cfg"
    GRUB_CONFIG_FILE="/boot/grub2/grub.cfg"
    # FIXME
    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
    cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
    grub-mkconfig -o "$GRUB_CONFIG_FILE"
}

function setup() {
    use_external_screen_if_available
    if ! in_X; then
		setfont ter-220n
	fi
	set_keyboard_layout
}

function chroot() {
    if has arch-chroot; then
	arch-chroot /mnt
    else
	env chroot /mnt
    fi
}

function use_my_bashrc() {
    bash --rcfile <(wget -q -O - "$BASHRC_URL")
}

function main() {
    download_self || true
    setup
    mount_partitions
    use_my_bashrc
}

set -e
set -o pipefail

main
