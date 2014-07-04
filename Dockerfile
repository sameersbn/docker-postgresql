FROM sameersbn/ubuntu:12.04.20140628
MAINTAINER sameer@damagehead.com

RUN apt-get update && \
		apt-get install -y postgresql postgresql-client && \
		rm -rf /var/lib/postgresql &&  \
		apt-get clean # 20140525

ADD start /start
RUN chmod 755 /start

EXPOSE 5432
VOLUME ["/var/lib/postgresql"]
CMD ["/start"]
