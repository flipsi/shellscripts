#!/usr/bin/env bash

# TODO: try this in babashka

set -e

function require {
  hash "$1" 2>/dev/null || {
    echo >&2 "Error: '$1' is required, but was not found."; exit 1;
  }
}

server_mac_address='ac:1f:6b:b5:2d:42'
server_name="verliernix"
server_path="/mnt/zfs/flipsi"
mountpoint="/mnt/verliernix-zfs-flipsi"

require mountpoint
require sshfs

function ping_server {
    ping -c1 "$server_name" >/dev/null 2>/dev/null
}

function wake_server {
    require wakeonlan
    wakeonlan "$server_mac_address" > /dev/null
}

function wait_for_server {
    echo -n "Waiting for $server_name to come up."
    LOOP_LENGTH=30
    # shellcheck disable=SC2034
    for i in $(seq 1 "$LOOP_LENGTH"); do
        echo -n "."
        if ping_server; then
            return
        else
            sleep 1
        fi
    done
    echo -e "\nFATAL ERROR: Could not bring up $server_name"
}

function send_server_to_sleep {
    require ssh
    # Requires poweroff command to be executable without password. You may have to add the following
    # line to /etc/sudoers via `sudo visudo`:
    # %sudo ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff
    ssh "$server_name" 'sudo poweroff'
}

function mount_server {
    # options=(-o reconnect -o compression=yes -o 'user_allow_other,default_permissions')
    options=(-o reconnect -o compression=yes) # mount as user
    sshfs $server_name:$server_path "$mountpoint" "${options[@]}"
}

function unmount_server {
    umount "$mountpoint"
}


function main {

    # shellcheck disable=SC2155 # (we need 'local' to not abort the script if subshell fails)
    local was_server_awake=$(ping_server && echo 'TRUE')
    if ! [[ $was_server_awake = 'TRUE' ]]; then
        echo "$server_name does not appear to be reachable."
        echo "Assuming we're in the correct local network, trying WakeOnLan ..."
        wake_server
        wait_for_server
    else
        echo "$server_name is online."
    fi

    # I don't want to mount via SSHFS and use local rsync, but prefer rsync over ssh instead
    # (see https://unix.stackexchange.com/a/284061/119362).

    echo -e "Executing backup script now.\n"
    # `backup` is a script expected to be in $PATH
    /usr/bin/env backup

    echo # newline

    if ! [[ $was_server_awake = 'TRUE' ]]; then
        echo "Sending $server_name back to sleep now."
        send_server_to_sleep
    fi

    echo "All done."
}

main


