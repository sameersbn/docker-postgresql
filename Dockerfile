ARG ALPINE_VERSION=edge
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# ~~~~~~~ CREATE BUILD BASE ~~~~~~~
FROM alpine:${ALPINE_VERSION} AS base
RUN \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo -e "\033[93m===== Downloading dependencies =====\033[0m" && \
    apk add --update tzdata acl bash curl tar perl python libuuid libxml2 libldap libxslt xz su-exec && \
    (rm -rf /var/cache/apk/* > /dev/null || true) && (rm -rf /tmp/* > /dev/null || true) && \
    mkdir -p /tmp/files/

# ~~~~~~~ BUILD POSTGRESQL ~~~~~~~
FROM base
LABEL maintainer="Bojan Cekrlic <https://github.com/bokysan/postgresql>"
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="PostgreSQL 13.4 Kitchensink edition" \
      org.label-schema.description="PostgreSQL 13.4 on Alphine linux, with lots of optional modules" \
      org.label-schema.url="https://github.com/bokysan/postgresql" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/bokysan/postgresql" \
      org.label-schema.vendor="Boky" \
      org.label-schema.version="11.2-01" \
      org.label-schema.schema-version="1.0"

ENV PG_VERSION=13.4
ENV PG_APP_HOME="/etc/docker-postgresql" \
    PG_USER=postgres \
    PG_DATABASE=postgres \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/run/postgresql \
    PG_LOGDIR=/var/log/postgresql \
    PG_CERTDIR=/etc/postgresql/certs \
    LANG=en_US.utf8

# Set to true/anything if you want to enable WAL archiving (e.g. for hot standby, point-in-time recovery)
#ENV PG_LOG_ARCHIVING=true
ENV PG_LOG_ARCHIVING_COMMAND="/var/lib/postgresql/wal-backup.sh %p %f"
ENV PG_BINDIR=/usr/bin/ \
    PG_DATADIR=${PG_HOME}/${PG_VERSION}/main \
    MUSL_LOCPATH=${LANG}

COPY files/* /tmp/files/
RUN \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo -e "\033[93m===== Downloading build dependencies =====\033[0m" && \
    apk add --virtual .build-deps util-linux-dev python-dev perl-dev openldap-dev libxslt-dev libxml2-dev build-base linux-headers libressl-dev zlib-dev make gcc pcre-dev zlib-dev ncurses-dev readline-dev && \
    echo -e "\033[93m===== Downloading Postgres: https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2 =====\033[0m" && \
    cd /tmp && \
    curl -O --retry 5 --max-time 300 --connect-timeout 10 -fSL https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2 && \
    curl -O --retry 5 --max-time 300 --connect-timeout 10 -fSL https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2.md5 && \
    if ! md5sum -c *.md5; then echo "MD5 sum not mached, cannot continue!"; exit 1; fi && \
    echo -e "\033[93m===== Extracing Postgres =====\033[0m" && \
    cat /tmp/postgres*.tar.bz2 | tar xfj - && \
    mv /tmp/postgresql-${PG_VERSION} /tmp/postgres && \
    cd /tmp/postgres && \
    # explicitly update autoconf config.guess and config.sub so they support more arches/libcs
    curl -o config/config.guess --retry 5 --max-time 300 --connect-timeout 10 -fSL 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb' && \
    curl -o config/config.sub --retry 5 --max-time 300 --connect-timeout 10 -fSL 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb' && \
    if [ -f /tmp/files/*.patch ]; then for i in /tmp/files/*.patch; do patch -p1 -i $i; done; fi && \
    rm -f /tmp/postgres*.tar.bz2 && \
    echo -e "\033[93m===== Building Postgres, please be patient... =====\033[0m" && \
    cd /tmp/postgres && \
    ./configure \
	--build=$CBUILD \
	--host=$CHOST \
	--enable-integer-datetimes \
	--enable-thread-safety \
	--prefix=/usr \
	--mandir=/usr/share/man \
	--with-openssl \
	--with-ldap \
	--with-libxml \
	--with-libxslt \
	--with-perl \
	--with-python \
	--with-system-tzdata=/usr/share/zoneinfo \
	--with-libedit-preferred \
	--with-uuid=e2fs && \
	make -j4 world && make install && make -C contrib install && \
	install -D -m755 /tmp/files/postgresql.initd /etc/init.d/postgresql && \
	install -D -m644 /tmp/files/postgresql.confd /etc/conf.d/postgresql && \
	install -D -m755 /tmp/files/pg-restore.initd /etc/init.d/pg-restore && \
	install -D -m644 /tmp/files/pg-restore.confd /etc/conf.d/pg-restore && \
	echo -e "\033[93m===== Cleaning up =====\033[0m" && \
	apk del .build-deps && \
	(rm -rf /var/cache/apk/* > /dev/null || true) && (rm -rf /tmp/* > /dev/null || true) && \
	(rm -rf /usr/src/postgresql /usr/local/share/doc /usr/local/share/man || true) && \
	echo -e "\033[93m===== Preparing environment =====\033[0m" && \
	mkdir /docker-entrypoint-initdb.d && \
	mkdir -p ${PG_HOME}/wal-backup && chown -R ${PG_USER}:${PG_USER} ${PG_HOME}/wal-backup && \
	rm -rf /tmp/files

COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
COPY wal-backup.sh ${PG_HOME}/wal-backup.sh

RUN \
	chmod 755 /sbin/entrypoint.sh && \
	chmod 755 ${PG_HOME}/wal-backup.sh

HEALTHCHECK --interval=10s --timeout=5s --retries=6 CMD (netstat -an | grep :5432 | grep LISTEN && echo "SELECT 1" | psql -1 -Upostgres -v ON_ERROR_STOP=1 -hlocalhost postgres) || exit 1
EXPOSE 5432/tcp
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
