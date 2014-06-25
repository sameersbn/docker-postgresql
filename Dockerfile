FROM sameersbn/ubuntu:12.04.20140519
MAINTAINER sameer@damagehead.com

RUN apt-get update && \
		apt-get install -y postgresql-9.1 postgresql-client-9.1 && \
		apt-get clean # 20140525

ADD assets/ /app/
RUN chmod 755 /app/init /app/setup/install
RUN /app/setup/install

ADD authorized_keys /root/.ssh/

EXPOSE 5432

VOLUME ["/var/lib/postgresql"]

ENTRYPOINT ["/app/init"]
CMD ["app:start"]
