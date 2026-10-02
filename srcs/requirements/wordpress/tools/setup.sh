#!/bin/bash
set -e

mkdir -p /run/php
mkdir -p /var/www/html

echo "Waiting for MariaDB..."

until mariadb-admin ping \
	-h mariadb \
	-u "${MYSQL_USER}" \
	-p"${MYSQL_PASSWORD}" \
	--silent
do
	sleep 1
done

echo "MariaDB is ready."

if [ ! -f /var/www/html/wp-config.php ]; then
	wp core download \
		--path=/var/www/html \
		--allow-root

	wp config create \
		--path=/var/www/html \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${MYSQL_PASSWORD}" \
		--dbhost="mariadb:3306" \
		--allow-root
fi

if ! wp core is-installed \
	--path=/var/www/html \
	--allow-root
then
	wp core install \
		--path=/var/www/html \
		--url="${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email \
		--allow-root

	wp user create \
		"${WP_USER}" \
		"${WP_USER_EMAIL}" \
		--path=/var/www/html \
		--user_pass="${WP_USER_PASSWORD}" \
		--role=author \
		--allow-root
fi

chown -R www-data:www-data /var/www/html

exec "$@"
