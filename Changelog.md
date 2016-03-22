# Changelog

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
