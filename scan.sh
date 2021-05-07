#!/usr/bin/env bash

set -e

# Using SANE (https://wiki.archlinux.org/index.php/SANE)

# show available scanners with `scanimage --list-devices`
DEVICE='escl:http://192.168.0.14:80'

GIVEN_OUTPUT_FILE="$1"
GIVEN_EXTENSION="${GIVEN_OUTPUT_FILE##*.}"

if [[ -z "$GIVEN_OUTPUT_FILE" ]]; then
    echo "ERROR: Please provide output file name."
    exit 1
elif [[ -e "$GIVEN_OUTPUT_FILE" ]]; then
    echo "ERROR: File $GIVEN_OUTPUT_FILE already exists."
    exit 1
fi

GIVEN_OUTPUT_DIR=$(dirname "$GIVEN_OUTPUT_FILE")
if [[ ! -d "$GIVEN_OUTPUT_DIR" ]]; then
    mkdir "$GIVEN_OUTPUT_DIR"
fi

if [[ "$GIVEN_EXTENSION" = "pdf" ]]; then
    EXTENSION="png"
    OUTPUT_FILE=$(mktemp -u /tmp/scan.XXXX.png)
else
    EXTENSION="$GIVEN_EXTENSION"
    OUTPUT_FILE="$GIVEN_OUTPUT_FILE"
fi

echo "Scanning..."
scanimage --device "$DEVICE" --format="$EXTENSION" --output-file "$OUTPUT_FILE" --progress

if [[ "$GIVEN_EXTENSION" = "pdf" ]]; then
    convert "$OUTPUT_FILE" "$GIVEN_OUTPUT_FILE"
    # rm "$OUTPUT_FILE" # doesn't hurt to keep it
fi
