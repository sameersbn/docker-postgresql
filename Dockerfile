FROM sameersbn/ubuntu:14.04.20150120
MAINTAINER sameer@damagehead.com

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y postgresql-9.1 postgresql-client-9.1 pwgen \
 && rm -rf /var/lib/postgresql \
 && rm -rf /var/lib/apt/lists/* # 20141001

ADD start /start
RUN chmod 755 /start

EXPOSE 5432

VOLUME ["/var/lib/postgresql"]
VOLUME ["/run/postgresql"]

CMD ["/start"]
