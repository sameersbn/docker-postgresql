FROM sameersbn/ubuntu:12.04.20140628
MAINTAINER sameer@damagehead.com

RUN apt-get update && \
		apt-get install -y postgresql postgresql-client && \
		apt-get clean # 20140525

ADD assets/ /app/
RUN chmod 755 /app/init /app/setup/install
RUN /app/setup/install

EXPOSE 5432

VOLUME ["/var/lib/postgresql"]

CMD ["/app/init"]
