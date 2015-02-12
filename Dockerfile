FROM sameersbn/ubuntu:14.04.20150120
MAINTAINER sameer@damagehead.com

ENV PG_VERSION 9.4

RUN groupadd -g 600 postgres &&\
    useradd postgres -m -g 600 -s /bin/bash -u 600

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} pwgen \
 && rm -rf /var/lib/postgresql \
 && rm -rf /var/lib/apt/lists/* # 20141001

ADD start /start
RUN chmod 755 /start

EXPOSE 5432

VOLUME ["/var/lib/postgresql"]
VOLUME ["/run/postgresql"]

CMD ["/start"]
