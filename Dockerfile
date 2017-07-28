FROM ubuntu:14.04
MAINTAINER me@fmartingr.com

ENV PG_APP_HOME="/etc/docker-postgresql"\
    PG_VERSION=9.6 \
    PG_POSTGIS_VERSION=2.3 \
    PG_USER=postgres \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/run/postgresql \
    PG_LOGDIR=/var/log/postgresql \
    PG_CERTDIR=/etc/postgresql/certs

ENV PG_BINDIR=/usr/lib/postgresql/${PG_VERSION}/bin \
    PG_DATADIR=${PG_HOME}/${PG_VERSION}/main \
    PG_CONFDIR=/etc/postgresql/${PG_VERSION}/main

RUN apt-get -y update && apt-get -y install wget \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y acl \
       # PostgreSQL
       postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} postgresql-contrib-${PG_VERSION} \
       # PostGIS support
       postgresql-contrib-${PG_VERSION} postgresql-${PG_VERSION}-postgis-${PG_POSTGIS_VERSION} \
       postgresql-${PG_VERSION}-postgis-${PG_POSTGIS_VERSION}-scripts \
 && rm -rf ${PG_HOME} \
 && rm -rf /var/lib/apt/lists/* \
 && apt-get remove -y wget

COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 5432/tcp

VOLUME ["${PG_DATADIR}", "${PG_RUNDIR}", "${PG_CONFDIR}"]
WORKDIR "${PG_HOME}"

ENTRYPOINT ["/sbin/entrypoint.sh"]
