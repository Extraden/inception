FROM debian:bookworm

RUN apt-get update \
	&& apt-get install -y \
	php8.2-fpm \
	php8.2-mysql \
	mariadb-client \
	curl \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp \
	https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

RUN mkdir -p /run/php \
	&& sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 9000|' \
	/etc/php/8.2/fpm/pool.d/www.conf

WORKDIR /var/www/html

COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]

CMD ["php-fpm8.2", "-F"]
