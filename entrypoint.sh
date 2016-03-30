#!/bin/bash
set -e
source ${PG_APP_HOME}/functions

[[ ${DEBUG} == true ]] && set -x

# allow arguments to be passed to postgres
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == postgres || ${1} == $(which postgres) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

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

  echo "Starting PostgreSQL ${PG_VERSION}: ${PG_BINDIR}/postgres -D ${PG_DATADIR} ${EXTRA_ARGS}"
  exec gosu postgres ${PG_BINDIR}/postgres -D ${PG_DATADIR} ${EXTRA_ARGS}
else
  # Our scripts for checking if postgres is online may produce non-zero exit codes.
  # Make sure bash doesn't stop executing when such command is encountered.
  set +e

  # This second flow is only usable with DOCKER EXEC or DOCKER RUN.
  # We will check how we are executed (basically if postgres is running or not)
  # Please note that IT IS A VERY BAD IDEA to run anothe posgres instance
  # From a RUNNING postgres directory. So, to sum up:
  # - use "docker exec" to enter a running instance
  # - use "docker run" to modify the data of an existing (shut-down) instance, if you try to do it on 
  #   an already running instance, YOU WILL CRASH IT.
  [[ ${DEBUG} == true ]] && echo "Verifying if we are running from an existing container..."
  [[ ${DEBUG} == true ]] && gosu postgres pg_ctl -D "$PG_DATADIR" status
  [[ ${DEBUG} == true ]] && echo "Will execute: exec gosu postgres" "$@"

  if [ `gosu postgres pg_ctl -D "$PG_DATADIR" status 2>&1 | grep -q "server is running"` ]; then
    # Support the "exec" option

    [ ${DEBUG} == true ]] && "We're in an existing container, execute the command: $@"
    exec gosu postgres "$@"
  else
    # Support the "run" option

    start_postgres_daemon
    exec gosu postgres "$@"
    stop_postgres_daemon
  fi
fi

