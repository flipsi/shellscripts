#!/usr/bin/env bash

set -e

[ "${BASH_VERSINFO:-0}" -ge 4 ] || (echo "Bash version >= 4 required, sorry." && exit 1)

SCRIPTNAME=$(basename "$0")

function _print_help_msg() {
    cat <<-EOF
$SCRIPTNAME - play some web radio

SYNOPSIS

    $SCRIPTNAME [OPTIONS] [QUERY|URL]

DESCRIPTION

    $SCRIPTNAME is a small script to conveniently play some web radio, e.g. on a Raspberry Pi.

NOTE

    Either provide a query to search for saved radio stations or provide a web radio URL.
    If a URL is provided, it will start playing immmediately.
    If the query matches exactly one station, it will pick it and start playing immmediately.
    If the query matches more than one station, you can pick a station interactively.

OPTIONS

    --list | -l                 List available radio stations (hardcoded in this script).

    --detach | -i               Start in the background.

    --kill | -k                 Stop any radio that was started in the background.

    --non-interactive | -n      Stop any radio that was started in the background.

    --help | -h                 Print this help message.

EOF
}

function require() {
    if ! (command -v "$1" >/dev/null); then
        echo "ERROR: Command $1 required. Please install the corresponding package!"
        exit 1
    fi
}

require vlc
require fzf


declare -A RADIO_STATION_LIST
RADIO_STATION_LIST["Brainradio Klassik"]="http://brainradioklassik.stream.laut.fm/brainradioklassik"
RADIO_STATION_LIST["Radio Swiss Jazz"]="http://www.radioswissjazz.ch/live/mp3.m3u"
RADIO_STATION_LIST["Soul Radio"]="http://soulradio02.live-streams.nl:80/live"
RADIO_STATION_LIST["fip Radio"]="http://direct.fipradio.fr/live/fip-midfi.mp3"


# ALSA audio device to use (list with `aplay -L`)
# If device not found, this will be ignored and default device will be used.
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=sndrpihifiberry,DEV=0}"

PIDFILE=/tmp/radiopi_playback.pid


function _test_audio_stream_url() {
    local URL="$1"
    # unfortunately doesn't work for some stations
    STATION_WHITELIST=(
        "${RADIO_STATION_LIST["Radio Swiss Jazz"]}"
        "${RADIO_STATION_LIST["fip Radio"]}"
    )
    # 'array contains'
    if printf '%s\n' "${STATION_WHITELIST[@]}" | grep -q -P "^$URL$"; then
        return 0
    fi
    CONTENT_TYPE=$(timeout 3s curl -sI -f -o /dev/null -w '%{content_type}\n' "$URL")
    if [[ "$CONTENT_TYPE" =~ ^audio/ ]]; then
        return 0
    else
        return 1
    fi
}

function _list_stations() {
    for STATION in "${!RADIO_STATION_LIST[@]}"; do echo $STATION; done
}

function _pick_station_interactively() {
    local QUERY_PREFILL="$1"
    _list_stations | fzf -q "$QUERY_PREFILL"
}

function _start_playback() {
    local AUDIO_SRC="$1"
    if ! _test_audio_stream_url "$AUDIO_SRC"; then
        echo "ERROR: $AUDIO_SRC does not look like an audio source."
        exit 2
    fi
    if aplay -L | grep -q "$ALSA_DEVICE"; then
        # echo "Using device $ALSA_DEVICE"
        VLC_OUTPUT_ARGS=(--aout=alsa --alsa-audio-device="$ALSA_DEVICE")
    fi
    VLC_ARGS=(
        "${VLC_OUTPUT_ARGS[@]}" \
        --gain=0.3 \
        --volume-step=1 \
        --no-volume-save \
        "$AUDIO_SRC"
    )
    if [[ -n "$DETACH" ]]; then
        cvlc "${VLC_ARGS[@]}" & echo $! > $PIDFILE
    else
        cvlc "${VLC_ARGS[@]}"
    fi
}

function _stop_playback() {
    if [[ ! -f ${PIDFILE} ]]; then
        echo "WARNING: Did not find PID file ${PIDFILE}"
    else
        PID=$(cat ${PIDFILE})
        if ps "${PID}" >/dev/null; then
            echo "Killing process with PID ${PID}"
            kill "${PID}" && rm ${PIDFILE}
        else
            echo "WARNING: No process found with PID ${PID}"
            rm ${PIDFILE}
        fi
    fi
}

function _main() {
    local QUERY_OR_URL="$1"
    if [[ -n "$QUERY_OR_URL" ]] && _test_audio_stream_url "$QUERY_OR_URL"; then
        AUDIO_SRC="$QUERY_OR_URL"
    elif [[ -n "$QUERY_OR_URL" && -n "${RADIO_STATION_LIST[$QUERY_OR_URL]}" ]]; then
        AUDIO_SRC="${RADIO_STATION_LIST[$QUERY_OR_URL]}"
    elif [[ -n "$NON_INTERACTIVE" ]]; then
        echo "ERROR: Station not found"
        exit 1
    else
        STATION=$(_pick_station_interactively "$QUERY_OR_URL")
        if [[ -z "$STATION" ]]; then
            echo "No station selected."
            exit 1
        else
            AUDIO_SRC="${RADIO_STATION_LIST[$STATION]}"
        fi
    fi
    _start_playback "$AUDIO_SRC"
}


while [[ $# -gt 0 ]]; do
    ARG="$1"
    case $ARG in
        --help|-h)
            _print_help_msg;
            exit 0
            ;;
        --list|-l)
            _list_stations;
            exit 0
            ;;
        --non-interactive|-n)
            NON_INTERACTIVE=1;
            shift
            ;;
        --detach|-d)
            DETACH=1;
            shift
            ;;
        --kill|-k)
            _stop_playback;
            exit 0
            ;;
        *)
            QUERY_OR_URL=$ARG
            shift
            ;;
    esac
done

_main "$QUERY_OR_URL"
