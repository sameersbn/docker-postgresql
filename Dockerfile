FROM sameersbn/ubuntu:14.04.20141026
MAINTAINER sameer@damagehead.com

RUN apt-get update \
 && apt-get install -y postgresql postgresql-client pwgen \
 && rm -rf /var/lib/postgresql \
 && rm -rf /var/lib/apt/lists/* # 20141001

ADD start /start
RUN chmod 755 /start

EXPOSE 5432

VOLUME ["/var/lib/postgresql"]
VOLUME ["/run/postgresql"]

CMD ["/start"]
