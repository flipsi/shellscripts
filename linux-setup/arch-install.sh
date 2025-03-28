#!/bin/bash

set -e

echo "Not meant to be executed as a script! Please do it manually!"
exit 1

loadkeys de
setfont ter-220n

ping google.com


##############################
# partitions and filesystems #
##############################

# partition setup
cfdisk /dev/nvme0n1
# /dev/nvme0n1p1 512M	EFI System			Type EFI System
# /dev/nvme0n1p2 4G		Boot partition		Type Linux filesystem
# /dev/nvme0n1p3 REST	LUKS				Type Linux LVM

# filesystems
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 -L boot /dev/nvme0n1p2

# LUKS encrypted partition
luksVolume=luks_root
luksGroup=mySuperGroup
cryptsetup luksFormat /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 $luksVolume

# LVM setup
pvcreate /dev/luks/$luksGroup # wrong?
vgcreate $luksGroup /dev/luks/$luksVolume # wrong?
lvcreate -L 32GB $luksGroup -n swap
lvcreate -L 200GB $luksGroup -n arch-root
lvcreate -L 100GB $luksGroup -n ubuntu-root
lvcreate -l 100%FREE $luksGroup -n home
# If a logical volume will be formatted with ext4, leave at least 256 MiB free space in the volume group to allow using e2scrub(8). After creating the last volume with -l 100%FREE, this can be accomplished by reducing its size with
lvreduce -L -256M $luksGroup/home.

mkfs.ext4 /dev/$luksGroup/arch-root
mkfs.ext4 /dev/$luksGroup/ubuntu-root
mkfs.ext4 /dev/$luksGroup/home


##################
# Generate fstab #
##################

# mount all the things
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount /dev/nvme0n1p2 /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot/efi
mount /dev/$luksGroup/root /mnt
mount /dev/$luksGroup/home /mnt/home

mkswap /dev/$luksGroup/swap
swapon /dev/$luksGroup/swap

# generate fstab
mkdir /mnt/etc
genfstab -L /mnt >> /mnt/etc/fstab


############################
# Install and launch Linux #
############################

# install basic packages
# pacstrap -K /mnt base linux linux-firmware \
pacstrap -K /mnt base linux-lts linux-firmware \
	base-devel git \
	lvm2 \
	netctl dhcpcd wpa_supplicant dialog \
	bash-completion neovim man-db man-pages

# Use the new system!
arch-chroot /mnt

# install more
pacman -S sudo openssh ssh-tools inetutils


#######################
# BASIC CONFIGURATION #
#######################

# disable annoying beep in console
nvim /etc/inputrc
# set bell-style none

# Time zone
# (normally `timedatectl set-timezone Europe/Berlin` would do it, but that doesn't work in chroot)
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

hwclock --systohc

# Localization
nvim /etc/locale.gen
# en_US.UTF-8
# de_DE.UTF-8
locale-gen
export MY_LOCALE='en_US.UTF-8'
echo "LANG=$MY_LOCALE" > /etc/locale.conf

MY_HOSTNAME=something
echo $MY_HOSTNAME > /etc/hostname

nvim /etc/vconsole.conf
# KEYMAP=de-latin1

nvim /etc/hosts
# 127.0.0.1	localhost
# ::1		    localhost
# 127.0.1.1	$MY_HOSTNAME.localdomain	myhostname

echo "EDITOR=/usr/bin/vim" > /etc/environment

####################
# create initramfs #
####################

# normally not required, but with LVM it has to be done again!

nvim /etc/mkinitcpio.conf
# add `encrypt` and `lvm2` steps to hooks:
# HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)
mkinitcpio -p linux


######################
# network management #
######################

systemctl enable netctl
systemctl enable systemd-resolved.service

# config in /etc/netctl

# config /etc/resolv.conf manually if resolved does not work

###################
# user management #
###################

# create root password
passwd

# create my user
useradd -m -g users -G wheel flipsi
passwd flipsi

# configure sudo
#
visudo
# 1) uncomment `wheel` thing to grant members sudo privileges
#
# OPTIONAL:
#
# 2) Allow more than 3 attempts before failure by adding this line:
# Defaults passwd_tries=5

# 3) Don't ask again after 5 minutes by adding this line:
# Defaults timestamp_timeout=30

# 4) Don't time out with sudden prompt, e.g. when buildind and installing packages with yay by adding this line {https://wiki.archlinux.org/title/sudo}:
# Defaults passwd_timeout=0



#####################################
# install and configure boot loader #
#####################################

########################################
# ALTERNATIVE 1) using the good old grub

pacman -S grub efibootmgr dosfstools mtools os-prober

nvim /etc/default/grub
# GRUB_CMDLINE_LINUX="cryptdevice=/dev/nvme0n1p3:VOLUMEGROUP:allow-discards quiet loglevel=3"
# GRUB_ENABLE_CRYPTODISK=y

# install grub to EFI partition
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
grub-mkconfig -o /boot/grub/grub.cfg # on ubuntu this is wrapped in a script `update-grub`


########################################
# ALTERNATIVE 2) using the modern refind
#

pacman -S refind
refind-install

# mkinitcpio -P

####################
# reboot and enjoy #
####################
exit # chroot

reboot
