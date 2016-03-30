FROM alpine:edge
MAINTAINER sameer@damagehead.com

ENV PG_APP_HOME="/etc/docker-postgresql" \
    PG_VERSION=9.5.1 \
    PG_USER=postgres \
    PG_DATABASE=postgres \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/run/postgresql \
    PG_LOGDIR=/var/log/postgresql \
    PG_CERTDIR=/etc/postgresql/certs \
    PG_LOG_ARCHIVING=false \
    PG_LOG_ARCHIVING_COMMAND="" \
    GOSU_VERSION=1.7 \
    LANG=en_US.utf8

ENV PG_BINDIR=/usr/bin/ \
    PG_DATADIR=${PG_HOME}/${PG_VERSION}/main \
    MUSL_LOCPATH=${LANG}



RUN \
    export ARCH=$(uname -m) && \
    if [ "$ARCH" == "x86_64" ]; then export ARCH=amd64; fi && \
    if [[ "$ARCH" == "i*" ]]; then export ARCH=i386; fi && \
    if [[ "$ARCH" == "arm*" ]]; then export ARCH=armhf; fi && \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    apk update && \
    apk add \
      acl \
      bash \
      curl \
      "postgresql@edge>=${PG_VERSION}" \
      "postgresql-client@edge>=${PG_VERSION}" \
      "postgresql-contrib>=${PG_VERSION}" \
      && \
    mkdir /docker-entrypoint-initdb.d && \
    curl -fsSL -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${ARCH}" && \
    chmod +x /usr/local/bin/gosu && \
    apk del curl && \
    rm -rf /var/cache/apk/*


COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh


EXPOSE 5432/tcp
VOLUME ["${PG_HOME}", "${PG_RUNDIR}"]
WORKDIR ${PG_HOME}
ENTRYPOINT ["/sbin/entrypoint.sh"]
