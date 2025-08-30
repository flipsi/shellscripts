#!/bin/bash

# Helper to conveniently use a Linux live environment and automate recurring setup commands.
# Note that this script is not generic and very specific to my personal needs and convention.

# Usage:
#     wget -q -O - "$SELF_URL" | bash -i
# Or:
#     curl -L "$SELF_URL" | bash -i

function print_usage() {
    cat <<-EOF
Flipsi's convenient Linux live environment helper.

Usage: $(basename "$0") [FUNCTION]

Invoke with specific function name or omit to execute everything.

EOF
}

# Resources:
#
# GRUB on Fedora
# https://docs.fedoraproject.org/en-US/quick-docs/grub2-bootloader/
# https://www.baeldung.com/linux/grub-menu-management


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
ROOT_PARTITION="/dev/$LUKS_GROUP/fedora-root"
HOME_PARTITION="/dev/$LUKS_GROUP/home"


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
    sudo mount -o bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
    sudo mount "$EFI_PARTITION" /mnt/boot/efi
    sudo mount "$HOME_PARTITION" /mnt/home
    for d in dev proc run sys; do
	sudo mount -o bind "/$d" "/mnt/$d"
    done
    lsblk --fs
}

# FIXME
function reinstall_grub() {
    # The grub2-mkconfig comman creates a new configuration based on the currently running system. It collects information from the /boot partition (or directory), from the /etc/default/grub file, and the customizable scripts in /etc/grub.d.
    # The configuration format is changing with time, and a new configuration file can become slightly incompatible with the older versions of the bootloader. Always run grub2-install before you create the configuration file with grub2-mkconfig.
    #
    # Under EFI, GRUB2 looks for its configuration in /boot/efi/EFI/fedora/grub.cfg, however the postinstall script of grub2-common installs a small shim which chains to the standard configuration at /boot/grub2/grub.cfg.
    #
    # First, we should look at how the GRUB menu entries are stored. The usual way is to keep definitions of entries in the /boot/grub2/grub.cfg file in the menuentry blocks. However, Fedora 30 adopted the BootLoaderSpec (BLS) specification, which demands keeping each entry definition in a separate file. We can find these files in the /boot/loader/entries folder.
    #
    # On Fedora, `grubby` was used for a while to manage GRUB menu entries. But it's deprecated and unmaintained now.

    SYSTEM_CONFIG_FILE="/etc/default/grub"
    # GRUB_CONFIG_FILE="/boot/grub/grub.cfg" # what a pitfall
    GRUB_CONFIG_FILE="/boot/grub2/grub.cfg"

    GRUB_INSTALL_BINARY=$(if has grub2-install; then echo grub2-install; else echo grub-install; fi)
    GRUB_MKCONFIG_BINARY=$(if has grub2-mkconfig; then echo grub2-mkconfig; else echo grub-mkconfig; fi)

    # dnf reinstall grub2-efi grub2-efi-modules shim-\*
    # dnf reinstall os-prober

    # install GRUB bootloader to EFI partition
    # force flag to ignore warning about only working when safe boot is disabled
    eval "$GRUB_INSTALL_BINARY" --target=x86_64-efi --bootloader-id=grub_uefi --recheck --force

    # vim "$SYSTEM_CONFIG_FILE"
    ## GRUB_ENABLE_BLSCFG="true"

    # generate grub configuration on boot partition
    cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
    eval "$GRUB_MKCONFIG_BINARY" -o "$GRUB_CONFIG_FILE"
}

function setup() {
    use_external_screen_if_available
    if ! in_X; then
	setfont ter-220n
    fi
    set_keyboard_layout
}

function chroot() {
    # FIXME use in new bash (sourcing this file without executing main?)
    if has arch-chroot; then
	sudo arch-chroot /mnt
    else
	sudo env chroot /mnt
    fi
}

function use_my_bashrc() {
    # FIXME seems to immediately 'exit'
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

if [[ "$1" = '--help' ]]; then
    print_usage
elif [[ -n "$1" ]]; then
    eval "$1"
else
    main
fi

# sync && exit
