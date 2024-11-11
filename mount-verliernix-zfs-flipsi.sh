#!/usr/bin/env bash

set -e

function require {
  hash "$1" 2>/dev/null || {
    echo >&2 "Error: '$1' is required, but was not found."; exit 1;
  }
}

require sshfs

server_name="verliernix"
server_path="/mnt/zfs/flipsi"
mountpoint="/mnt/verliernix-zfs-flipsi"

# options=(-o reconnect -o compression=yes -o 'user_allow_other,default_permissions')
options=(-o reconnect -o compression=yes) # mount as user

sshfs $server_name:$server_path $mountpoint "${options[@]}"
