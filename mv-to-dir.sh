#!/usr/bin/env bash

set -e

function _print_help_msg()
{
    echo "Move a given file to a directory - which will be created with the same name (without the extention)"
    echo "Usage: $(basename "$0") FILE [...]"
}

function main()
{
    if [ "$#" -eq 1 ]; then
        file="$1"
        if ! [[ -e "$file" ]]; then
            echo "ERROR: File $file does not exist."
            exit 1
        fi
        name_of_dir="${file%.*}"
        if [[ -e "$name_of_dir" ]]; then
            echo "ERROR: $name_of_dir already exists."
            exit 1
        else
            mkdir "$name_of_dir"
            mv "$file" "$name_of_dir"
        fi
    else
        name_of_dir="$(mktemp -d -p "$PWD" dir-XXXX)"
        for file in "${@}"; do
            mv "$file" "$name_of_dir"
        done
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Pass at least one file as argument!"
elif [[ "$1" == "--help" ]]; then
    _print_help_msg
    exit
else
    main "$@"
fi
