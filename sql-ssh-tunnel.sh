#!/bin/bash

set -e

function usage() {
  cat <<-EOF
Use SQL over ssh tunnel via a jumphost

Usage: $(basename "$0") [OPTIONS] [PASS-THROUGH-OPTIONS]

  OPTIONS:
  =======
  --help                       Print this help message.
  -t type  | --db-type=type    Type of the database, one of ['mysql', 'pgsql']. Defaults to 'mysql'.
  -j host  | --jumphost=host   Host to ssh to. Will be inferred if omitted.
  -J user  | --jumpuser=user   ssh user for jumphost. Will be inferred if omitted.
  -h host  | --host=host       Database hostname to connect to.
  -u user  | --user=user       Database user.
  -p pass  | --password=pass   Database user's password.
  -D name  | --database=name   Database to connect to.
  --source-only                Don't do anything (enable import for other scripts).

  PASS-THROUGH-OPTIONS:
  ====================
  Every unknown option will be passed through to the SQL client as is.

EOF
}


DEFAULT_DB_TYPE="mysql"
DEFAULT_JUMPHOST="quz.example.com"
DEFAULT_JUMPUSER="$(whoami)"

SSH_TUNNEL_SOCKET_FILE="ssh-tunnel-socket"
MYSQL_PORT=3306
PGSQL_PORT=5432


function parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help)
        usage;
        exit 0
        ;;
      -t)
        CFG_DB_TYPE="$2"
        shift; shift
        ;;
      --db-type=*)
        CFG_DB_TYPE="${1#*=}"
        shift
        ;;
      -j)
        CFG_JUMPHOST="$2"
        shift; shift
        ;;
      --jumphost=*)
        CFG_JUMPHOST="${1#*=}"
        shift
        ;;
      -J)
        CFG_JUMPUSER="$2"
        shift; shift
        ;;
      --jumpuser=*)
        CFG_JUMPUSER="${1#*=}"
        shift
        ;;
      -h)
        CFG_HOST="$2"
        shift; shift
        ;;
      --host=*)
        CFG_HOST="${1#*=}"
        shift
        ;;
      -u)
        CFG_USER="$2"
        shift; shift
        ;;
      --user=*)
        CFG_USER="${1#*=}"
        shift
        ;;
      -p)
        CFG_PASS="$2"
        shift; shift
        ;;
      --password=*)
        CFG_PASS="${1#*=}"
        shift
        ;;
      -D)
        CFG_DATABASE="$2"
        shift; shift
        ;;
      --database=*)
        CFG_DATABASE="${1#*=}"
        shift
        ;;
      --source-only)
        CFG_SOURCE_ONLY=true
        shift
        ;;
      *)
        PASS_THROUGH_ARGS+=("$1")
        shift
        ;;
    esac
  done
}


function validate_config() {
  if [[ -z "${CFG_DB_TYPE}" ]]; then
    CFG_DB_TYPE="$DEFAULT_DB_TYPE"
  elif [[ "${CFG_DB_TYPE}" != "mysql" && "${CFG_DB_TYPE}" != "pgsql" ]]; then
    echo "Unsupported database type: ${CFG_DB_TYPE}. Please use 'mysql' or 'pgsql'".
    exit 2
  fi
  if [[ -z "${CFG_USER}" ]]; then
    echo "Please specify database user."
    exit 2
  fi
  if [[ "${CFG_DB_TYPE}" = "pgsql" && -z "${CFG_DATABASE}" ]]; then
    echo "Please specify database name."
    exit 2
  fi
}


function infer_jump_config() {
  if [[ -z "${CFG_JUMPHOST}" ]]; then
    case "$CFG_HOST" in
      *foo.example.com)
        CFG_JUMPHOST="bar.example.com"
        ;;
      *)
        CFG_JUMPHOST="$DEFAULT_JUMPHOST"
        ;;
    esac
  fi
  if [[ -z "${CFG_JUMPUSER}" ]]; then
    CFG_JUMPUSER="$DEFAULT_JUMPUSER"
  fi
}


function find_unused_port() {
  for PORT in {9666..9999}
  do
    if ! lsof -i :$PORT >/dev/null; then
      break
    fi
  done
  echo $PORT
}


# return port
function open_tunnel() {
  local PORT
  PORT=$(find_unused_port)
  case ${CFG_DB_TYPE} in
    mysql )
      ORIGINAL_PORT="${MYSQL_PORT}"
      ;;
    pgsql )
      ORIGINAL_PORT="${PGSQL_PORT}"
      ;;
  esac
  ssh \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -M -S "$SSH_TUNNEL_SOCKET_FILE" \
    -fnNT \
    -L "$PORT:$CFG_HOST:$ORIGINAL_PORT" \
    "$CFG_JUMPUSER@$CFG_JUMPHOST"
  echo "$PORT"
}


function close_tunnel() {
  ssh -S "$SSH_TUNNEL_SOCKET_FILE" -O exit "$CFG_JUMPUSER@$CFG_JUMPHOST"
}


# param $1 port
function start_mysql_shell() {
  local PORT
  PORT=$1
  mysql \
    --user="$CFG_USER" \
    --password="$CFG_PASS" \
    --host="localhost" \
    --protocol="TCP" \
    --port="$PORT" \
    "${PASS_THROUGH_ARGS[@]}" \
    "$CFG_DATABASE"
}


# param $1 port
function start_psql_shell() {
  local PORT
  local PG_CONNECTION_STRING
  PORT=$1
  PG_CONNECTION_STRING=postgres://${CFG_USER}:${CFG_PASS}@127.0.0.1:${PORT}/${CFG_DATABASE}
  psql "${PASS_THROUGH_ARGS[@]}" --dbname="$PG_CONNECTION_STRING"
}



parse_arguments "$@"
validate_config
infer_jump_config

if [[ -z "$CFG_SOURCE_ONLY" ]]; then
  echo -e "\\nRunning $(basename "$0") on $(date)"
  PORT=$(open_tunnel)
  case ${CFG_DB_TYPE} in
    mysql )
      start_mysql_shell "$PORT"
      ;;
    pgsql )
      start_psql_shell "$PORT"
      ;;
  esac
  close_tunnel
else
  echo "$(basename "$BASH_SOURCE") loaded"
fi
