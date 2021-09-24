#!/bin/bash

# Author: "Philipp Moers" <soziflip@gmail.com>

set -e
set -o pipefail

DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPTNAME=$(basename "$0")

function print_help_msg() {
    cat <<-EOF
$SCRIPTNAME - Playing some audio with increasing volume

Usage:

    $SCRIPTNAME start [--no-volume-increment] [URL]  # start alarm (optional stream URL)
    $SCRIPTNAME stop                                 # stop alarm
    $SCRIPTNAME <0-100>                              # set volume
    $SCRIPTNAME enable <hour> <minute> [<duration>]  # schedule daily alarm for <hour>:<minute>
    $SCRIPTNAME disable                              # remove scheduled alarm

EOF
}


function require() {
    if ! (command -v "$1" >/dev/null); then
        echo "ERROR: Command $1 required. Please install the corresponding package!"
        exit 1
    fi
}

require vlc
require nc
require pactl


##########
# CONFIG #
##########

DEFAULT_DURATION=60

# TODO: adjust and normalize volume for pool
VOLUME_INITIAL=60
VOLUME_INCREMENT_COUNT=15
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=5

AUDIO_SRC= # will be set by arg or picked from pool
AUDIO_SRC_POOL=(\
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://www.radioswissjazz.ch/live/mp3.m3u \
    http://192.211.51.158:5014 \
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
    http://radio.netstream.ch/128k \
    http://19763.live.streamtheworld.com:3690/977_OLDIES_SC \
    http://bluford.torontocast.com:8626/stream \
    http://s6.voscast.com:11312 \
    https://streamer.radio.co/s2c3cc784b/listen \
    http://fluxfm.hoerradar.de/flux-jazzschwarz-mp3-hq \
    )
AUDIO_SRC_FALLBACK="/home/sflip/snd/Mark Ronson feat. Bruno Mars - Uptown Funk.mp3"

PIDFILE_AUDIO=/tmp/alarm_audio.pid
PIDFILE_VOLUME_INCREMENT=/tmp/alarm_volume_increment.pid

# Optional ALSA audio device to use (list with `aplay -L`)
# If not set, vlc output will not be overwritten
ALSA_DEVICE="$ALSA_DEVICE"

VLC_RC_HOST=localhost
VLC_RC_PORT=9879

# suffix appended to crontab line, will be grepped for and matched lines will be deleted!
ALARM_CRON_ID="MANAGED ALARM CRON"


##########
# SCRIPT #
##########

function check_vlc_volume_is_decoupled_from_system_volume() {
    if ! grep -q -E '^flat-volumes = no' '/etc/pulse/daemon.conf'; then
        cat <<-EOF
ERROR: Please decouple vlc volume from system volume by adding
'flat-volumes = no'
to your /etc/pulse/daemon.conf For details, see
https://superuser.com/questions/770028/decoupling-vlc-volume-and-system-volume
EOF
        exit 1
    fi
}

function configure_vlc_netcat_cmd() {
    local NETCAT_HELP_OUTPUT
    NETCAT_HELP_OUTPUT=$(nc -h 2>&1)
    if grep -q '^GNU netcat' <(echo "$NETCAT_HELP_OUTPUT" | head -n 1); then
        VLC_NETCAT_CMD="nc -c $VLC_RC_HOST $VLC_RC_PORT"
    elif grep -q '^OpenBSD netcat' <(echo "$NETCAT_HELP_OUTPUT" | head -n 1); then
        VLC_NETCAT_CMD="nc -N $VLC_RC_HOST $VLC_RC_PORT"
    else
        echo 'ERROR: Unknown netcat version!'
        exit 1
    fi
}

function configure_vlc_env() {
    export DISPLAY=${DISPLAY:-":0"}
    export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-"unix:path=/run/user/$(id -u)/bus"}
}

function configure_vlc_output_args() {
    if [[ -n $ALSA_DEVICE ]]; then
        VLC_OUTPUT_ARGS=(--aout=alsa --alsa-audio-device="$ALSA_DEVICE")
    fi
}

function wait_until_tcp_port_open() {
    local HOST="$1"
    local PORT="$2"
    local SLEEP="0.02"
    while ! nc -z "$HOST" "$PORT"; do
        sleep "$SLEEP"
    done
}

function set_system_volume() {
    local VOLUME="$1"
    SINK=$(pactl -- list short sinks | cut -f1)
    pactl -- set-sink-volume "${SINK}" "${VOLUME}%"
    echo "Set system volume to ${VOLUME}%"
}

function set_vlc_volume() {
    local VOLUME="$1"
    echo "volume ${VOLUME}" | ${VLC_NETCAT_CMD}
    echo "Set vlc volume to ${VOLUME}"
}

function increase_vlc_volume() {
    local VOLUME="$1"
    echo "volup ${VOLUME}" | ${VLC_NETCAT_CMD}
    echo "Increased vlc volume by ${VOLUME}"
}

function decrease_vlc_volume() {
    local VOLUME="$1"
    echo "voldown ${VOLUME}" | ${VLC_NETCAT_CMD}
    echo "Decreased vlc volume by ${VOLUME}"
}

function test_audio_stream_url() {
    local URL="$1"
    CONTENT_TYPE=$(timeout 3s curl -sI -f -o /dev/null -w '%{content_type}\n' "$URL")
    if [[ "$CONTENT_TYPE" =~ ^audio/ ]]; then
        return 0
    else
        return 1
    fi
}

function pick_audio_src() {
    if [[ -z $PICK_AUDIO_SRC_ATTEMPTS ]]; then
        PICK_AUDIO_SRC_ATTEMPTS=0
    fi
    local SRC="$1"
    if [[ -n $SRC ]]; then
        AUDIO_SRC="$SRC"
    else
        AUDIO_SRC=${AUDIO_SRC_POOL[$RANDOM % ${#AUDIO_SRC_POOL[@]}]}
    fi
    (( PICK_AUDIO_SRC_ATTEMPTS=PICK_AUDIO_SRC_ATTEMPTS+1))
    if [[ "$PICK_AUDIO_SRC_ATTEMPTS" -ge 5 ]]; then
        echo "Maximum attempts reached! Using fallback audio source ${AUDIO_SRC_FALLBACK}"
        AUDIO_SRC="${AUDIO_SRC_FALLBACK}"
    elif ! test_audio_stream_url "${AUDIO_SRC}"; then
        echo "Audio source ${AUDIO_SRC} does not look like an audio source. Trying another one..."
        pick_audio_src
    else
        echo "Audio source set to: ${AUDIO_SRC}"
    fi
}

function start_alarm() {
    # https://wiki.videolan.org/Documentation:Command_line/
    echo "Starting audio player..."
    vlc \
        "${VLC_OUTPUT_ARGS[@]}" \
        --gain=1.0 \
        --volume-step=1 \
        --no-volume-save \
        -I rc --rc-host=$VLC_RC_HOST:$VLC_RC_PORT \
        "${AUDIO_SRC}" & echo $! > ${PIDFILE_AUDIO}
    echo "Audio player PID: $(cat ${PIDFILE_AUDIO})"

    wait_until_tcp_port_open "$VLC_RC_HOST" "$VLC_RC_PORT"
    set_vlc_volume ${VOLUME_INITIAL}

    # increase volume step by step (in background)
    if [[ -z "$VOLUME_INCREMENT_DISABLED" ]]; then
        (
        for (( i = 0; i < VOLUME_INCREMENT_COUNT; i++ )); do
            sleep ${VOLUME_INCREMENT_FREQUENCY}
            increase_vlc_volume ${VOLUME_INCREMENT_AMOUNT}
        done

        rm ${PIDFILE_VOLUME_INCREMENT}
        ) & echo $! > ${PIDFILE_VOLUME_INCREMENT}
        echo "Volume increment PID: $(cat ${PIDFILE_VOLUME_INCREMENT})"
    else
        echo Playing at constant volume.
    fi
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

function append_once() {
    FILE="$1"
    LINE="$2"
    grep -q -F "$LINE" "$FILE"  || echo "$LINE" >> "$FILE"
}


function open_crontab() {
    TMP_CRONTAB=$(mktemp "/tmp/crontab.XXX.txt")
    crontab -l > "$TMP_CRONTAB"
}

function close_crontab() {
    # cat "$TMP_CRONTAB" # debug
    cat "$TMP_CRONTAB" | crontab -
}

function enable_alarm() {
    local ALPHA_HOUR="$1"
    local ALPHA_MINUTE="$2"
    local DURATION="$3"
    local OMEGA_HOUR=$(  date -d "$ALPHA_HOUR:$ALPHA_MINUTE $DURATION minutes" +'%H')
    local OMEGA_MINUTE=$(date -d "$ALPHA_HOUR:$ALPHA_MINUTE $DURATION minutes" +'%M')
    open_crontab
    disable_alarm_2
    append_once "$TMP_CRONTAB" "ALARM_CMD=${DIR}/$SCRIPTNAME"
    append_once "$TMP_CRONTAB" "ALARM_LOG=/tmp/$SCRIPTNAME.log"
    ALPHA_LINE="$ALPHA_MINUTE $ALPHA_HOUR * * * \$ALARM_CMD start >>\$ALARM_LOG 2>&1 # $ALARM_CRON_ID"
    OMEGA_LINE="$OMEGA_MINUTE $OMEGA_HOUR * * * \$ALARM_CMD stop  >>\$ALARM_LOG 2>&1 # $ALARM_CRON_ID"
    append_once "$TMP_CRONTAB" "$ALPHA_LINE"
    append_once "$TMP_CRONTAB" "$OMEGA_LINE"
    close_crontab
    echo "Scheduled alarm for $ALPHA_HOUR:$ALPHA_MINUTE."
}

function disable_alarm() {
    open_crontab
    disable_alarm_2
    close_crontab
    echo "Removed scheduled alarm."
}

function disable_alarm_2() {
    awk -i inplace -v rmv="$ALARM_CRON_ID" '!index($0,rmv)' "$TMP_CRONTAB"
}



# # ensure that pactl works from cron
# PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
# export PULSE_RUNTIME_PATH
# if [[ ! -w "${PULSE_RUNTIME_PATH}" ]]; then
#     echo "Warning: Please adjust permissions of ${PULSE_RUNTIME_PATH}"
# fi


check_vlc_volume_is_decoupled_from_system_volume
configure_vlc_netcat_cmd
configure_vlc_env
configure_vlc_output_args

if [[ -z $1 ]]; then
    print_help_msg
elif [[ $1 = "start" ]]; then
    echo "------------------------------------"
    echo "alarm.sh started at $(date +'%F %R')"
    if [[ "$2" = '--no-volume-increment' ]]; then
        VOLUME_INCREMENT_DISABLED=1
        VOLUME_INITIAL=$((VOLUME_INITIAL + VOLUME_INCREMENT_AMOUNT * VOLUME_INCREMENT_COUNT))
        pick_audio_src "$3"
    else
        pick_audio_src "$2"
    fi
    start_alarm
elif [[ $1 = "stop" ]]; then
    stop_alarm
elif [[ $1 = "enable" && -n "$2" && "$2" =~ ^[0-9]{1,2}$ && -n "$3" && "$3" =~ ^[0-9]{1,2}$ ]]; then
    if [[ -n "$4" && "$4" =~ ^[0-9]{1,2}$ ]]; then
        DURATION="$4"
    else
        DURATION="$DEFAULT_DURATION"
    fi
    require crontab
    enable_alarm "$2" "$3" "$DURATION"
elif [[ $1 = "disable" ]]; then
    require crontab
    disable_alarm
elif [[ $1 =~ ^[+-]?[0-9]+$ ]]; then
    set_vlc_volume "$1"
else
    print_help_msg
fi



