#!/usr/bin/env bash

timestamp=$(date +%Y-%m-%d-%H-%M)
for file in "${@}"; do
    backup_file="$file.$timestamp.bak"
    if touch "$backup_file" > /dev/null 2> /dev/null; then
        cp -r "$file" "$backup_file"
    else
        sudo cp -r "$file" "$backup_file"
    fi
done
