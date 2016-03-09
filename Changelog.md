# Changelog

11.2-02
- make sure that extension names are quoted to make it possible to work with extensions with a dash in the name

11.2-01
- switch to Postgres 11.2
- switched from gosu to su-exec as it's even smaller and available in alpine repository
- optimized package management by using `apk --virtual` keyword

**10.5-02**
- added an option to create multiple usernames at the time of initialization
- switched to multistage build which should help building things a bit faster

**10.5-01**
- upgraded ot Postgres 10.5
- added compatibility layer to be able to create database with the same variables as with the original image

**10.4-01**
- upgraded Postgres to 10.4
- upgraded GOSU to 1.10
- removed depricated MAINTAINER tag and replaced it with LABEL

**9.6.2-02**
- forced listening on all interfaces on startup
- added a docker HEALTCHECK command to the container

**9.6.2-01**
- upgraded to 9.6.2
- fix for misbehaved PG_LOG_ARCHIVING variable

**9.6.1-01**
- postgresql: upgraded to 9.6.1
- fix for `wal-backup.sh` script which misbehaved

**9.6.0-01**
- postgresql: upgraded to 9.6.0

**9.5**
- postgresql: upgrade to 9.5

**9.4-17**
- added `DB_EXTENSION` configuration parameter

**9.4-12**
- removed use of single-user mode
- added `DB_TEMPLATE` variable to specify the database template

**9.4-11**
- added `PG_PASSWORD` variable to specify password for `postgres` user

**9.4-9**
- complete rewrite
- `PSQL_TRUST_LOCALNET` config parameter renamed to `PG_TRUST_LOCALNET`
- `PSQL_MODE` config parameter renamed to `REPLICATION_MODE`
- `PSQL_SSLMODE` config parameter renamed to `REPLICATION_SSLMODE`
- defined `/etc/postgresql/certs` as the mountpoint to install SSL key and certificate
- added `PG_SSL` parameter to enable/disable SSL support
- `DB_LOCALE` config parameter renamed to `PG_LOCALE`
- complete rewrite of the README
- add support for creating backups using `pg_basebackup`
- removed `PG_LOCALE` option (doesn't work!)
- added `DEBUG` option to enable bash debugging

**9.4-2**
- added replication options

**9.4-1**
- start: removed `pwfile` logic
- init: added `USERMAP_*` configuration options
- base image update to fix SSL vulnerability

**9.4**
- postgresql: upgrade to 9.4

**9.1-2**
- use the official postgresql apt repo
- feature: automatic data migration on upgrade

**9.1-1**
- upgrade to sameersbn/ubuntu:20141001, fixes shellshock
- support creation of users and databases at launch (`docker run`)
- mount volume at `/var/run/postgresql` allowing the postgresql unix socket to be exposed

**9.1**
- optimized image size by removing `/var/lib/apt/lists/*`.
- update to the sameersbn/ubuntu:12.04.20140818 baseimage
- removed use of supervisord
