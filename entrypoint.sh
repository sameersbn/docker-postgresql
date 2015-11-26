#!/bin/bash
set -e

PSQL_SSLMODE=${PSQL_SSLMODE:-}

PG_TRUST_LOCALNET=${PG_TRUST_LOCALNET:-$PSQL_TRUST_LOCALNET} # backward compatibility
PG_TRUST_LOCALNET=${PG_TRUST_LOCALNET:-false}

REPLICATION_MODE=${REPLICATION_MODE:-$PSQL_MODE} # backward compatibility
REPLICATION_MODE=${REPLICATION_MODE:-}
REPLICATION_USER=${REPLICATION_USER:-}
REPLICATION_PASS=${REPLICATION_PASS:-}
REPLICATION_HOST=${REPLICATION_HOST:-}
REPLICATION_PORT=${REPLICATION_PORT:-}

DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

DB_LOCALE=${DB_LOCALE:-C}
DB_UNACCENT=${DB_UNACCENT:-false}

PG_CONF=${PG_DATADIR}/postgresql.conf
PG_HBA_CONF=${PG_DATADIR}/pg_hba.conf
PG_IDENT_CONF=${PG_DATADIR}/pg_ident.conf
PG_RECOVERY_CONF=${PG_DATADIR}/recovery.conf

## Execute command as PG_USER
exec_as_postgres() {
  sudo -HEu ${PG_USER} "$@"
}

map_uidgid() {
  USERMAP_ORIG_UID=$(id -u ${PG_USER})
  USERMAP_ORIG_GID=$(id -g ${PG_USER})
  USERMAP_GID=${USERMAP_GID:-${USERMAP_UID:-$USERMAP_ORIG_GID}}
  USERMAP_UID=${USERMAP_UID:-$USERMAP_ORIG_UID}
  if [[ ${USERMAP_UID} != ${USERMAP_ORIG_UID} ]] || [[ ${USERMAP_GID} != ${USERMAP_ORIG_GID} ]]; then
    echo "Adapting uid and gid for ${PG_USER}:${PG_USER} to $USERMAP_UID:$USERMAP_GID"
    groupmod -g ${USERMAP_GID} ${PG_USER}
    sed -i -e "s|:${USERMAP_ORIG_UID}:${USERMAP_GID}:|:${USERMAP_UID}:${USERMAP_GID}:|" /etc/passwd
  fi
}

locale_gen() {
  if [[ $DB_LOCALE != C ]]; then
    echo "Generating locale \"${DB_LOCALE}\"..."
    locale-gen ${DB_LOCALE} >/dev/null
  fi
}

create_datadir() {
  echo "Initializing datadir..."
  mkdir -p ${PG_HOME}
  if [[ -d ${PG_DATADIR} ]]; then
    find ${PG_DATADIR} -type f -exec chmod 0600 {} \;
    find ${PG_DATADIR} -type d -exec chmod 0700 {} \;
  fi
  chown -R ${PG_USER}:${PG_USER} ${PG_HOME}
}

create_logdir() {
  echo "Initializing logdir..."
  mkdir -p ${PG_LOGDIR}
  chmod -R 1775 ${PG_LOGDIR}
  chown -R root:${PG_USER} ${PG_LOGDIR}
}

create_rundir() {
  echo "Initializing rundir..."
  mkdir -p ${PG_RUNDIR} ${PG_RUNDIR}/${PG_VERSION}-main.pg_stat_tmp
  chmod -R 0755 ${PG_RUNDIR}
  chmod g+s ${PG_RUNDIR}
  chown -R ${PG_USER}:${PG_USER} ${PG_RUNDIR}
}

set_postgresql_param() {
  local key=${1}
  local value=${2}
  if [[ -n ${value} ]]; then
    local current=$(exec_as_postgres sed -n -e "s/^\("${key}" = '\)\([^ ']*\)\(.*\)$/\2/p" ${PG_CONF})
    if [[ "${current}" != "${value}" ]]; then
      echo "‣ Setting postgresql.conf parameter: ${key} = '${value}'"
      exec_as_postgres sed -i "s|^[#]*[ ]*"${key}" = .*|"${key}" = '"${value}"'|" ${PG_CONF}
    fi
  fi
}

set_recovery_param() {
  local key=${1}
  local value=${2}
  if [[ -n ${value} ]]; then
    local current=$(exec_as_postgres sed -n -e "s/^\(.*\)\("${key}"=\)\([^ ']*\)\(.*\)$/\3/p" ${PG_RECOVERY_CONF})
    if [[ "${current}" != "${value}" ]]; then
      echo "Updating primary_conninfo ${key}..."
      exec_as_postgres sed -i "s|"${key}"=[^ ']*|"${key}"="${value}"|" ${PG_RECOVERY_CONF}
    fi
  fi
}

set_hba_param() {
  local value=${1}
  if ! grep -q "$(sed "s| | \\\+|g" <<< ${value})" ${PG_HBA_CONF}; then
    echo "${value}" >> ${PG_HBA_CONF}
  fi
}

configure_hot_standby() {
  case ${REPLICATION_MODE} in
    slave|snapshot) ;;
    *)
      echo "Configuring hot standby..."
      set_postgresql_param "wal_level" "hot_standby"
      set_postgresql_param "max_wal_senders" "16"
      set_postgresql_param "checkpoint_segments" "8"
      set_postgresql_param "wal_keep_segments" "32"
      set_postgresql_param "hot_standby" "on"
      ;;
  esac
}

initialize_database() {
  if [[ ! -f ${PG_DATADIR}/PG_VERSION ]]; then
    case ${REPLICATION_MODE} in
      slave|snapshot)
        # default params
        REPLICATION_PORT=${REPLICATION_PORT:-5432}
        PSQL_SSLMODE=${PSQL_SSLMODE:-disable}

        if [[ -z $REPLICATION_HOST ]]; then
          echo "ERROR! Cannot continue without the REPLICATION_HOST. Exiting..."
          exit 1
        fi

        if [[ -z $REPLICATION_USER ]]; then
          echo "ERROR! Cannot continue without the REPLICATION_USER. Exiting..."
          exit 1
        fi

        if [[ -z $REPLICATION_PASS ]]; then
          echo "ERROR! Cannot continue without the REPLICATION_PASS. Exiting..."
          exit 1
        fi

        echo -n "Waiting for $REPLICATION_HOST to accept connections (60s timeout)"
        timeout=60
        while ! ${PG_BINDIR}/pg_isready -h $REPLICATION_HOST -p $REPLICATION_PORT -t 1 >/dev/null 2>&1
        do
          timeout=$(expr $timeout - 1)
          if [[ $timeout -eq 0 ]]; then
            echo "Timeout! Exiting..."
            exit 1
          fi
          echo -n "."
          sleep 1
        done
        echo

        case ${REPLICATION_MODE} in
          slave)
            echo "Replicating initial data from $REPLICATION_HOST..."
            exec_as_postgres PGPASSWORD=$REPLICATION_PASS ${PG_BINDIR}/pg_basebackup -D ${PG_DATADIR} \
              -h ${REPLICATION_HOST} -p ${REPLICATION_PORT} -U ${REPLICATION_USER} -X stream -w >/dev/null
            ;;
          snapshot)
            echo "Generating a snapshot data on $REPLICATION_HOST..."
            exec_as_postgres PGPASSWORD=$REPLICATION_PASS ${PG_BINDIR}/pg_basebackup -D ${PG_DATADIR} \
              -h ${REPLICATION_HOST} -p ${REPLICATION_PORT} -U ${REPLICATION_USER} -X fetch -w >/dev/null
        esac
        ;;
      *)
        echo "Initializing database..."
        PG_OLD_VERSION=$(find ${PG_HOME}/[0-9].[0-9]/main -maxdepth 1 -name PG_VERSION 2>/dev/null | grep -v $PG_VERSION | sort -r | head -n1 | cut -d'/' -f5)
        if [[ -n ${PG_OLD_VERSION} ]]; then
          echo "‣ Migrating PostgreSQL ${PG_OLD_VERSION} data to ${PG_VERSION}..."

          # protect the existing data from being altered by apt-get
          mv ${PG_HOME}/${PG_OLD_VERSION} ${PG_HOME}/${PG_OLD_VERSION}.migrating

          echo "‣ Installing PostgreSQL ${PG_OLD_VERSION}..."
          if ! ( apt-get update &&  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-${PG_OLD_VERSION} postgresql-client-${PG_OLD_VERSION} ) >/dev/null; then
            echo "ERROR! Failed to install PostgreSQL ${PG_OLD_VERSION}. Exiting..."
            # first move the old data back
            rm -rf ${PG_HOME}/${PG_OLD_VERSION}
            mv ${PG_HOME}/${PG_OLD_VERSION}.migrating ${PG_HOME}/${PG_OLD_VERSION}
            exit 1
          fi
          rm -rf /var/lib/apt/lists/*

          # we're ready to migrate, move back the old data and remove the trap
          rm -rf ${PG_HOME}/${PG_OLD_VERSION}
          mv ${PG_HOME}/${PG_OLD_VERSION}.migrating ${PG_HOME}/${PG_OLD_VERSION}
        fi

        exec_as_postgres ${PG_BINDIR}/initdb --pgdata=${PG_DATADIR} \
          --username=${PG_USER} --encoding=unicode --locale=${DB_LOCALE} --auth=trust >/dev/null

        if [[ -n ${PG_OLD_VERSION} ]]; then
          PG_OLD_BINDIR=/usr/lib/postgresql/${PG_OLD_VERSION}/bin
          PG_OLD_DATADIR=${PG_HOME}/${PG_OLD_VERSION}/main
          PG_OLD_CONF=${PG_OLD_DATADIR}/postgresql.conf
          PG_OLD_HBA_CONF=${PG_OLD_DATADIR}/pg_hba.conf
          PG_OLD_IDENT_CONF=${PG_OLD_DATADIR}/pg_ident.conf

          echo -n "‣ Migration in progress. Please be patient..."
          exec_as_postgres ${PG_BINDIR}/pg_upgrade \
            -b ${PG_OLD_BINDIR} -B ${PG_BINDIR} \
            -d ${PG_OLD_DATADIR} -D ${PG_DATADIR} \
            -o "-c config_file=${PG_OLD_CONF} --hba_file=${PG_OLD_HBA_CONF} --ident_file=${PG_OLD_IDENT_CONF}" \
            -O "-c config_file=${PG_CONF} --hba_file=${PG_HBA_CONF} --ident_file=${PG_IDENT_CONF}" >/dev/null
          echo
        fi
        ;;
    esac

    # configure path to data_directory
    set_postgresql_param "data_directory" "${PG_DATADIR}"

    # listen on all interfaces
    set_postgresql_param "listen_addresses" "*"

    # allow remote connections to postgresql database
    set_hba_param "host all all 0.0.0.0/0 md5"

    configure_hot_standby

    # Change DSM from `posix' to `sysv' if we are inside an lx-brand container
    if [[ $(uname -v) == "BrandZ virtual linux" ]]; then
      set_postgresql_param "dynamic_shared_memory_type" "sysv"
    fi
  fi
}

trust_localnet() {
  if [[ ${PG_TRUST_LOCALNET} == true ]]; then
    echo "Trusting connections from the local network..."
    set_hba_param "host all all samenet trust"
  fi
}

create_user() {
  if [[ -n ${DB_USER} ]]; then
    if [[ -z ${DB_PASS} ]]; then
      echo "ERROR! Please specify a password for DB_USER in DB_PASS. Exiting..."
      exit 1
    fi
    echo "Creating database user: ${DB_USER}"
    echo "CREATE ROLE \"${DB_USER}\" with LOGIN CREATEDB PASSWORD '${DB_PASS}';" | \
      exec_as_postgres ${PG_BINDIR}/postgres --single -D ${PG_DATADIR} >/dev/null 2>&1
  fi
}

create_database() {
  if [[ -n ${DB_NAME} ]]; then
    echo -n "Creating database(s): "
    for database in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<< "${DB_NAME}"); do
      echo -n "${database} "
      echo "CREATE DATABASE \"${database}\";" | \
        exec_as_postgres ${PG_BINDIR}/postgres --single -D ${PG_DATADIR} >/dev/null 2>&1

      if [[ ${DB_UNACCENT} == true ]]; then
        echo "CREATE EXTENSION IF NOT EXISTS unaccent;" | \
          exec_as_postgres ${PG_BINDIR}/postgres --single ${database} -D ${PG_DATADIR} >/dev/null 2>&1
      fi

      if [[ -n ${DB_USER} ]]; then
        echo "GRANT ALL PRIVILEGES ON DATABASE \"${database}\" to \"${DB_USER}\";" | \
          exec_as_postgres ${PG_BINDIR}/postgres --single -D ${PG_DATADIR} >/dev/null 2>&1
      fi
    done
    echo
  fi
}

create_replication_user() {
  case $REPLICATION_MODE in
    slave|snapshot) ;; # replication user can only be created on the master
    *)
      if [[ -n ${REPLICATION_USER} ]]; then
        if [[ -z ${REPLICATION_PASS} ]]; then
          echo "ERROR! Please specify a password for REPLICATION_USER in REPLICATION_PASS. Exiting..."
          exit 1
        fi

        echo "Creating replication user: ${REPLICATION_USER}"
        echo "CREATE ROLE \"${REPLICATION_USER}\" WITH REPLICATION LOGIN ENCRYPTED PASSWORD '${REPLICATION_PASS}';" | \
          exec_as_postgres ${PG_BINDIR}/postgres --single -D ${PG_DATADIR} >/dev/null 2>&1

        set_hba_param "host replication ${REPLICATION_USER} 0.0.0.0/0 md5"
      fi
      ;;
  esac
}

configure_recovery() {
  if [[ ! -f ${PG_RECOVERY_CONF} ]]; then
    if [[ ${REPLICATION_MODE} == slave ]]; then
      # initialize recovery.conf on the firstrun (slave only)
      echo "Configuring recovery..."
      exec_as_postgres touch ${PG_RECOVERY_CONF}
      ( echo "standby_mode = 'on'";
        echo "primary_conninfo = 'host=${REPLICATION_HOST} port=${REPLICATION_PORT} user=${REPLICATION_USER} password=${REPLICATION_PASS} sslmode=${PSQL_SSLMODE}'";
        echo "trigger_file = '/tmp/postgresql.trigger'" ) > ${PG_RECOVERY_CONF}
    fi
  else
    set_recovery_param "host"      "${REPLICATION_HOST}"
    set_recovery_param "port"      "${REPLICATION_PORT}"
    set_recovery_param "user"      "${REPLICATION_USER}"
    set_recovery_param "password"  "${REPLICATION_PASS}"
    set_recovery_param "sslmode"   "${PSQL_SSLMODE}"
  fi
}

# allow arguments to be passed to postgres
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == postgres || ${1} == $(which postgres) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# default behaviour is to launch postgres
if [[ -z ${1} ]]; then

  map_uidgid
  locale_gen

  create_datadir
  create_logdir
  create_rundir

  initialize_database
  trust_localnet

  create_user
  create_database
  create_replication_user
  configure_recovery

  echo "Starting PostgreSQL ${PG_VERSION}..."
  exec start-stop-daemon --start --chuid ${PG_USER}:${PG_USER} \
    --exec ${PG_BINDIR}/postgres -- -D ${PG_DATADIR} ${EXTRA_ARGS}
else
  exec "$@"
fi

