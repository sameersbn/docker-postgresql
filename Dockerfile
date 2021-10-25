ARG ALPINE_VERSION=alpine:latest

# ~~~~~~~ CREATE BUILD BASE ~~~~~~~
FROM ${ALPINE_VERSION} AS base
RUN \
    # echo "@${ALPINE_VERSION} http://nl.alpinelinux.org/alpine/${ALPINE_VERSION}/main" >> /etc/apk/repositories && \
    echo -e "\033[93m===== Downloading dependencies =====\033[0m" && \
    apk add --update tzdata acl bash curl tar perl python3 libuuid libxml2 libldap libxslt xz su-exec && \
    (rm -rf /var/cache/apk/* > /dev/null || true) && (rm -rf /tmp/* > /dev/null || true) && \
    mkdir -p /tmp/files/

# ~~~~~~~ BUILD POSTGRESQL ~~~~~~~
FROM base AS build

ENV LANG=en_US.utf8
ENV MUSL_LOCPATH=${LANG}

COPY files/* /tmp/files/
RUN \
    echo -e "\033[93m===== Downloading build dependencies =====\033[0m" && \
    apk add --virtual .build-deps util-linux-dev python3-dev perl-dev openldap-dev libxslt-dev libxml2-dev build-base linux-headers libressl-dev zlib-dev make gcc pcre-dev zlib-dev ncurses-dev readline-dev

ARG PG_VERSION
WORKDIR /tmp
RUN \
    echo -e "\033[93m===== Downloading Postgres: https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2 =====\033[0m" && \
    curl -O --retry 5 --max-time 300 --connect-timeout 10 -fSL https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2 && \
    curl -O --retry 5 --max-time 300 --connect-timeout 10 -fSL https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2.md5 && \
    if ! md5sum -c *.md5; then echo "MD5 sum not mached, cannot continue!"; exit 1; fi

RUN \
    echo -e "\033[93m===== Extracing Postgres =====\033[0m" && \
    cat /tmp/postgres*.tar.bz2 | tar xfj - && \
    mv /tmp/postgresql-${PG_VERSION} /tmp/postgres

WORKDIR /tmp/postgres
RUN \
    # explicitly update autoconf config.guess and config.sub so they support more arches/libcs
    curl -o config/config.guess --retry 5 --max-time 300 --connect-timeout 10 -fSL 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb' && \
    curl -o config/config.sub --retry 5 --max-time 300 --connect-timeout 10 -fSL 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb' && \
    if [ -f /tmp/files/*.patch ]; then for i in /tmp/files/*.patch; do patch -p1 -i $i; done; fi

RUN \
    echo -e "\033[93m===== Building Postgres, please be patient... =====\033[0m" && \
    cd /tmp/postgres && \
    ./configure \
        --build=$CBUILD \
        --host=$CHOST \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --prefix=/opt/postgresql \
        --mandir=/usr/share/man \
        --with-openssl \
        --with-ldap \
        --with-libxml \
        --with-libxslt \
        --with-perl \
        --with-python \
        --with-system-tzdata=/usr/share/zoneinfo \
        --with-libedit-preferred \
        --with-uuid=e2fs
RUN \
    make -j$(nproc) world

RUN \
    make install && make -C contrib install && \
    install -D -m755 /tmp/files/postgresql.initd /etc/init.d/postgresql && \
    install -D -m644 /tmp/files/postgresql.confd /etc/conf.d/postgresql && \
    install -D -m755 /tmp/files/pg-restore.initd /etc/init.d/pg-restore && \
    install -D -m644 /tmp/files/pg-restore.confd /etc/conf.d/pg-restore

# ~~~~~~~ RUN POSTGRESQL ~~~~~~~
FROM base
LABEL maintainer="Bojan Cekrlic <https://github.com/bokysan/postgresql>"
ARG PG_VERSION
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="PostgreSQL ${PG_VERSION} Kitchensink edition" \
      org.label-schema.description="PostgreSQL ${PG_VERSION} on Alphine linux, with lots of optional modules" \
      org.label-schema.url="https://github.com/bokysan/postgresql" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/bokysan/postgresql" \
      org.label-schema.vendor="Boky" \
      org.label-schema.version="${PG_VERSION}-01" \
      org.label-schema.schema-version="1.0"

ENV PG_APP_HOME="/etc/docker-postgresql"
ENV PG_USER=postgres
ENV PG_DATABASE=postgres
ENV PG_HOME=/var/lib/postgresql
ENV PG_RUNDIR=/run/postgresql
ENV PG_LOGDIR=/var/log/postgresql
ENV PG_CERTDIR=/etc/postgresql/certs
ENV PG_LOG_ARCHIVING_COMMAND="/var/lib/postgresql/wal-backup.sh %p %f"
ENV PG_BINDIR=/usr/bin/
ENV PG_DATADIR=${PG_HOME}/${PG_VERSION}/main

RUN addgroup -S ${PG_USER} && adduser -S -D -H ${PG_USER} ${PG_USER}

COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
COPY wal-backup.sh ${PG_HOME}/wal-backup.sh
COPY --from=build /etc/init.d/postgresql /etc/init.d/postgresql
COPY --from=build /etc/conf.d/postgresql /etc/conf.d/postgresql
COPY --from=build /etc/init.d/pg-restore /etc/init.d/pg-restore
COPY --from=build /etc/conf.d/pg-restore /etc/conf.d/pg-restore
COPY --from=build /opt/postgresql /opt/postgresql

RUN \
    echo -e "\033[93m===== Preparing environment =====\033[0m" && \
    ln -s /opt/postgresql/bin/* /usr/bin/
RUN \
    echo "PG_USER=${PG_USER}" && \
    mkdir -p ${PG_RUNDIR} && chown ${PG_USER}:${PG_USER} ${PG_RUNDIR} && \
    mkdir -p ${PG_LOGDIR} && chown ${PG_USER}:${PG_USER} ${PG_LOGDIR} && \
    mkdir -p ${PG_HOME} && chown ${PG_USER}:${PG_USER} ${PG_HOME} && \
    mkdir /docker-entrypoint-initdb.d && \
    mkdir -p ${PG_HOME}/wal-backup && chown ${PG_USER}:${PG_USER} ${PG_HOME}/wal-backup && \
    chmod 755 /sbin/entrypoint.sh && \
    chmod 755 ${PG_HOME}/wal-backup.sh

VOLUME ${PG_LOGDIR}
VOLUME ${PG_HOME}
HEALTHCHECK --interval=10s --timeout=5s --retries=6 CMD (netstat -an | grep :5432 | grep LISTEN && echo "SELECT 1" | psql -1 -Upostgres -v ON_ERROR_STOP=1 -hlocalhost postgres) || exit 1
EXPOSE 5432/tcp
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
