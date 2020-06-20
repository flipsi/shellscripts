#!/bin/bash

# Author: "Philipp Moers" <soziflip@gmail.com>

set -e

SCRIPTNAME=$(basename "$0")

function print_help_msg() {
    cat <<-EOF
$SCRIPTNAME - Playing some audio with increasing volume

Usage:
    $SCRIPTNAME start [URL]     # start alarm
    $SCRIPTNAME stop            # stop alarm
    $SCRIPTNAME <0-100>         # set volume

EOF
}


# We have to decouple vlc volume and system volume by setting
# `flat-volumes = no` in /etc/pulse/daemon.conf
# https://superuser.com/questions/770028/decoupling-vlc-volume-and-system-volume


##########
# CONFIG #
##########

# TODO: adjust and normalize volume for pool
VOLUME_INITIAL=140
VOLUME_INCREMENT_COUNT=8
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=1

AUDIO_SRC= # will be set by arg or picked from pool
AUDIO_SRC_POOL=(\
    http://192.211.51.158:5014 \
    http://198.50.158.92:8190 \
    http://209.236.126.18:8002 \
    http://198.7.62.157:8003 \
    http://66.85.88.18:5284 \
    http://95.211.3.65:8000 \
    http://192.240.102.133:11760/stream \
    https://internetradio.salue.de:8443/classicrock.mp3 \
    http://brainradioklassik.stream.laut.fm/brainradioklassik \
    http://direct.fipradio.fr/live/fip-midfi.mp3 \
    http://listento.thefunkstation.com:8000 \
    http://soulradio02.live-streams.nl:80/live \
    http://stream.srg-ssr.ch/m/rsj/mp3_128 \
    https://www.stream24.net/tune-in/r6247.m3u \
    http://cristina.torontocast.com:8022/stream \
    http://radio.netstream.ch/128k \
    http://19763.live.streamtheworld.com:3690/977_OLDIES_SC \
    http://edge01.media.positivityradio.world:8081/positively/60s128/icecast.audio \
    http://bluford.torontocast.com:8626/stream \
    http://s6.voscast.com:11312 \
    https://streamer.radio.co/s2c3cc784b/listen \
    http://fluxfm.hoerradar.de/flux-jazzschwarz-mp3-hq \
    )
AUDIO_SRC_FALLBACK="/home/sflip/snd/Selections_from_Disneys_Orchestra_Collection,_Vol._1-rNkSgsbbWfI.webm"

PIDFILE_AUDIO=/tmp/alarm_audio.pid
PIDFILE_VOLUME_INCREMENT=/tmp/alarm_volume_increment.pid

# ALSA audio device to use (list with `aplay -L`)
ALSA_DEVICE=${ALSA_DEVICE:-default}

VLC_RC_PORT=9879

## there are different versions of netcat (nc), one supporting -c the other supporting -N
# VLC_NETCAT_CMD="nc -c localhost ${VLC_RC_PORT}"
VLC_NETCAT_CMD="nc -N localhost ${VLC_RC_PORT}"


##########
# SCRIPT #
##########


function set_system_volume() {
    local VOLUME="$1"
    echo "Setting system volume: ${VOLUME}%"
    SINK=$(pactl -- list short sinks | cut -f1)
    pactl -- set-sink-volume "${SINK}" "${VOLUME}%"
}

function set_vlc_volume() {
    local VOLUME="$1"
    echo "Setting vlc volume: ${VOLUME}"
    echo "volume ${VOLUME}" | ${VLC_NETCAT_CMD}
}

function increase_vlc_volume() {
    local VOLUME="$1"
    echo "Increasing vlc volume: ${VOLUME}"
    echo "volup ${VOLUME}" | ${VLC_NETCAT_CMD}
}

function decrease_vlc_volume() {
    local VOLUME="$1"
    echo "Increasing vlc volume: ${VOLUME}"
    echo "voldown ${VOLUME}" | ${VLC_NETCAT_CMD}
}


function pick_audio_src() {
    local SRC="$1"
    if [[ -n $SRC ]]; then
        AUDIO_SRC="$SRC"
    else
        AUDIO_SRC=${AUDIO_SRC_POOL[$RANDOM % ${#AUDIO_SRC_POOL[@]}]}
    fi
    if [[ ${AUDIO_SRC} =~ ^http ]]; then
        if ! curl -ILsf "${AUDIO_SRC}" -o/dev/null; then
            echo "Audio source ${AUDIO_SRC} seems unreachable!"
            echo "Using fallback ${AUDIO_SRC_FALLBACK}"
            AUDIO_SRC="${AUDIO_SRC_FALLBACK}"
        fi
    fi

    echo "Audio source is ${AUDIO_SRC}"
}


function start_alarm() {
    echo "Starting audio player..."
    vlc \
        --aout=alsa --alsa-audio-device="$ALSA_DEVICE" \
        -I rc --rc-host=localhost:${VLC_RC_PORT} \
        "${AUDIO_SRC}" & echo $! > ${PIDFILE_AUDIO}
    echo "Audio player PID: $(cat ${PIDFILE_AUDIO})"

    sleep 0.1 # dirty hack to hope vlc interface is reachable
    set_vlc_volume ${VOLUME_INITIAL}

    # increase volume step by step (in background)
    (
    for (( i = 0; i < VOLUME_INCREMENT_COUNT; i++ )); do
        sleep ${VOLUME_INCREMENT_FREQUENCY}
        increase_vlc_volume ${VOLUME_INCREMENT_AMOUNT}
    done

    rm ${PIDFILE_VOLUME_INCREMENT}
    ) & echo $! > ${PIDFILE_VOLUME_INCREMENT}
    echo "Volume increment PID: $(cat ${PIDFILE_VOLUME_INCREMENT})"
}


function stop_alarm() {
    for PIDFILE in ${PIDFILE_VOLUME_INCREMENT} ${PIDFILE_AUDIO}; do
        if [[ ! -f ${PIDFILE} ]]; then
            echo "Warning: Did not find pidfile ${PIDFILE}"
        else
            PID=$(cat ${PIDFILE})
            if ps "${PID}" >/dev/null; then
                echo "Killing process with PID ${PID}"
                kill "${PID}" && rm ${PIDFILE}
            else
                echo "Warning: No process found with PID ${PID}"
                rm ${PIDFILE}
            fi
        fi
    done
}


# # ensure that pactl works from cron
# PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
# export PULSE_RUNTIME_PATH
# if [[ ! -w "${PULSE_RUNTIME_PATH}" ]]; then
#     echo "Warning: Please adjust permissions of ${PULSE_RUNTIME_PATH}"
# fi


if [[ -z $1 ]]; then
    print_help_msg
elif [[ $1 = "start" ]]; then
    echo "------------------------------------"
    echo "alarm.sh started at $(date +'%F %R')"
    # pick_audio_src "$2"
    pick_audio_src http://stream.srg-ssr.ch/m/rsj/mp3_128
    start_alarm
elif [[ $1 = "stop" ]]; then
    stop_alarm
elif [[ $1 =~ ^[+-]?[0-9]+$ ]]; then
    set_vlc_volume "$1"
else
    print_help_msg
fi



