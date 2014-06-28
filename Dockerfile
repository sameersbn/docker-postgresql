FROM sameersbn/ubuntu:12.04.20140628
MAINTAINER sameer@damagehead.com

RUN apt-get update && \
		apt-get install -y postgresql postgresql-client && \
		rm -rf /var/lib/postgresql &&  \
		apt-get clean # 20140525

ADD init /init
RUN chmod 755 /init

EXPOSE 5432
VOLUME ["/var/lib/postgresql"]
CMD ["/init"]
