#!/usr/bin/env bash

set -e

[ "${BASH_VERSINFO:-0}" -ge 4 ] || (echo "Bash version >= 4 required, sorry." && exit 1)

function require() {
    if ! (command -v "$1" >/dev/null); then
        echo "ERROR: Command $1 required. Please install the corresponding package!"
        exit 1
    fi
}

require vlc
require fzf


ALSA_AUDIO_DEVICE="${ALSA_AUDIO_DEVICE:-plughw:CARD=sndrpihifiberry,DEV=0}"


declare -A RADIO_STATION_LIST
RADIO_STATION_LIST["Brainradio Klassik"]="http://brainradioklassik.stream.laut.fm/brainradioklassik"
RADIO_STATION_LIST["Radio Swiss Jazz"]="http://www.radioswissjazz.ch/live/mp3.m3u"
RADIO_STATION_LIST["fip Radio"]="http://direct.fipradio.fr/live/fip-midfi.mp3"
RADIO_STATION_LIST["Soul Radio"]="http://soulradio02.live-streams.nl:80/live"



function _list_stations() {
    for STATION in "${!RADIO_STATION_LIST[@]}"; do echo $STATION; done
}

function _pick_station_interactively() {
    QUERY_PREFILL="$1"
    _list_stations | fzf -q "$QUERY_PREFILL"
}


function _play() {
    AUDIO_SRC="$1"
    cvlc \
        --aout=alsa --alsa-audio-device="$ALSA_AUDIO_DEVICE" \
        --gain=0.3 \
        --volume-step=1 \
        --no-volume-save \
        "$AUDIO_SRC"
}


STATION=$(_pick_station_interactively "$@")

if [[ -n "$STATION" ]]; then
    AUDIO_SRC="${RADIO_STATION_LIST[$STATION]}"
    _play "$AUDIO_SRC"
fi
