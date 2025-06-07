#!/usr/bin/env bash

server_mac_address='ac:1f:6b:b5:2d:42'
server_name="verliernix"
server_path="/mnt/zfs/flipsi"
mountpoint="/mnt/verliernix-zfs-flipsi"


function has {
    type "$1" > /dev/null 2>&1
}

function require {
    hash "$1" 2>/dev/null || {
        echo >&2 "Error: '$1' is required, but was not found."; exit 1;
    }
}

function pingable {
    ping -c 1 "$1" >/dev/null 2>&1
}

function wake {
    mac_address="$1"
    if has wol; then
        wol "$mac_address"
    else
        wakeonlan "$mac_address"
    fi
}

function ensure_mountpoint_dir_exists {
    if ! [[ -d "$mountpoint" ]]; then
        sudo mkdir -p "$mountpoint"
        sudo chown "$USER" "$mountpoint"
    fi
}

function mount_fileserver {
    if mountpoint -q "$mountpoint"; then
        echo "$mountpoint seems already mounted."
    else
        echo "Mounting $mountpoint now..."
        # options=(-o reconnect -o compression=yes -o 'user_allow_other,default_permissions')
        options=(-o reconnect -o compression=yes) # mount as user
        sshfs $server_name:$server_path $mountpoint "${options[@]}"
        echo "Mounted $mountpoint successfully."
    fi
}

function main {
    pingable "$server_name" || wake "$server_mac_address"
    ensure_mountpoint_dir_exists
    mount_fileserver
}

set -e
require sshfs
main

