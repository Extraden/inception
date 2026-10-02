FROM debian:bookworm

RUN apt-get update \
	&& apt-get install -y mariadb-server \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql/*

COPY conf/99-inception.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf

COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/setup.sh"]

CMD ["mariadbd", "--user=mysql"]
