#!/bin/bash
set -e

# shellcheck source=runtime/functions
source "${PG_APP_HOME}/functions"

[[ ${DEBUG} == true ]] && set -x

# This wigly-wagly code here is required to support spaces in the arguments.
# This will include the quotes around the parameters which include spaces.
declare EXTRA_ARGS=""
function parse_extra_args() {
  whitespace="[[:space:]]"
  # Bash will expand the array when the function is called so interate through
  # all the arguments of the function.
  for i in "${@}"; do
    if [[ $i =~ $whitespace ]]; then
        # Add qoutes around the parameter
        i=\"$i\"
    fi
    # Add add the parameter to the list...
    EXTRA_ARGS="$EXTRA_ARGS$i "
  done
}

# allow arguments to be passed to postgres
if [[ ${1:0:1} = '-' ]]; then
  parse_extra_args "${@}"
  set --
elif [[ ${1} == postgres || ${1} == $(command -v postgres) ]]; then
  EXTRA_ARGS="${@:2}"
elif [[ ${1} == postgres || ${1} == $(which postgres) ]]; then
  parse_extra_args "${@:2}"
  set --
fi
echo "PostgreSQL extra arguments: ${EXTRA_ARGS}"

setup_postgres() {
  map_uidgid

  create_datadir
  create_certdir
  create_logdir
  create_rundir

  set_resolvconf_perms

  configure_postgresql
}

# default behaviour is to launch postgres
if [[ -z ${1} ]]; then
  [[ ${DEBUG} == true ]] && echo "Will start up the daemon..."
  setup_postgres
  set_postgresql_param "listen_addresses" "*"
  start_postgres
else
  [[ ${DEBUG} == true ]] && echo "Going through the second workflow..."

  # Our scripts for checking if postgres is online may produce non-zero exit codes.
  # Make sure bash doesn't stop executing when such command is encountered.
  set +e

  # This second flow is only usable with DOCKER EXEC or DOCKER RUN.
  # We will check how we are executed (basically if postgres is running or not)
  # Please note that IT IS A VERY BAD IDEA to run another postgres instance
  # From a RUNNING postgres directory. So, to sum up:
  # - use "docker exec" to enter a running instance
  # - use "docker run" to modify the data of an existing (shut-down) instance, if you try to do it on
  #   an already running instance, YOU WILL CRASH IT.
  [[ ${DEBUG} == true ]] && echo "Verifying if we are running from an existing container..."
  [[ ${DEBUG} == true ]] && su-exec postgres pg_ctl -D "$PG_DATADIR" status
  [[ ${DEBUG} == true ]] && echo "Will execute: exec su-exec postgres" "$@"
  [[ ${DEBUG} == true ]] && su-exec postgres pg_ctl -D "$PG_DATADIR" status

  if [ `su-exec postgres pg_ctl -D "$PG_DATADIR" status 2>&1 | grep -q "server is running"` ]; then
    # Support the "exec" option

    [ ${DEBUG} == true ]] && "We're in an existing container, execute the command: $@"
    exec su-exec postgres "$@"
  else
    # Support the "run" option

    start_postgres_daemon
    exec su-exec postgres "$@"
    stop_postgres_daemon
  fi
fi
