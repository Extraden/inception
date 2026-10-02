#!/bin/bash
set -e

mkdir -p /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d "/var/lib/mysql/mysql" ]; then
	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql

	mariadbd \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--skip-networking &

	MARIADB_PID=$!

	until mariadb-admin -u root ping --silent; do
		sleep 1
	done

	mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${MYSQL_DATABASE}\`.*
TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost'
IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'${HOSTNAME}';
DROP DATABASE IF EXISTS test;

FLUSH PRIVILEGES;

SHUTDOWN;
EOF

	wait "$MARIADB_PID"
fi

exec "$@"
