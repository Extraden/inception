# Inception — User documentation

## Services and access

Inception runs a WordPress site backed by MariaDB. An NGINX container serves the site over HTTPS; WordPress/PHP-FPM and MariaDB are internal services and are not intended to be accessed directly from outside the Docker network.

- **Website:** `https://dsemenov.42.fr`
- **Administration panel:** `https://dsemenov.42.fr/wp-admin`
- **Host entry point:** HTTPS on port `443` only
- **Certificate:** self-signed; a browser warning is expected

The domain must resolve to the VM's IP (often `127.0.0.1` when browsing **inside** the VM). The developer's setup instructions explain how to edit `/etc/hosts`.

## Start and stop the application

Run these commands **from the repository root** (`~/inception` for the example setup):

~~~bash
make          # builds images and starts the services in the background
make ps       # displays running service containers
make logs     # follows logs; Ctrl+C stops log viewing, not the services
make stop     # stops containers without deleting them
make start    # starts already-created containers
make restart  # restarts current containers
make down     # removes Compose containers and network, preserves named volumes
make up       # builds and starts the stack again
~~~

Use `make` or `make up` after changes that require rebuilding images. `make restart` does **not** rebuild images or automatically apply changed environment variables to existing containers.

**Do not use `docker compose down -v`** unless you deliberately want to destroy the application's Docker volumes and persistent data.

After a VM reboot, run `make` if the application has not already started automatically.

## WordPress usage

Open the website in a browser and accept the self-signed certificate warning only if you are on the expected, locally configured VM.

To manage content:

1. Open `https://dsemenov.42.fr/wp-admin`.
2. Sign in with the administrator username and password configured on the first install.
3. Use **Pages → All Pages** or **Posts → All Posts**, edit content, and click **Update/Publish**.
4. Refresh the public page to verify the changes.
5. Sign out when finished.

The project creates two WordPress accounts during initial installation:

- An **administrator** set by `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD`.
- A second **author** account set by `WP_USER` / `WP_USER_PASSWORD`.

The administrator's actual username must **not** contain `admin` or `administrator` in any capitalization. The environment variable name `WP_ADMIN_USER` is allowed.

## Credentials: location and management

Runtime configuration resides in the local file `srcs/.env` **inside the VM**. It is ignored by Git. It contains database credentials and the initial WordPress credentials; do not publish it, include it in screenshots, or commit it.

The configuration includes `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `DOMAIN_NAME`, `WP_TITLE`, `WP_ADMIN_USER`, `WP_ADMIN_PASSWORD`, `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_PASSWORD` and `WP_USER_EMAIL`.

**Important:** Changing values in `srcs/.env` after the initial installation **does not automatically change existing MariaDB or WordPress account passwords** in their persistent databases. Use the appropriate WordPress administration/password reset workflow or database account-management procedure, then keep the runtime configuration consistent. Avoid copying real passwords into bug reports.

## Health checks

From the repository root:

~~~bash
make ps
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs --tail=50
curl -kI https://dsemenov.42.fr
~~~

Healthy operation means:

- The three services (`nginx`, `wordpress`, `mariadb`) are running.
- The HTTPS request responds successfully (typically `HTTP/1.1 200 OK`).
- The website shows the configured WordPress site, **not** the WordPress installation screen.
- Editing a page in the administration panel updates the public page.
- Plain HTTP (port `80`) is not available through the project.

The `-k` option in `curl` is only for testing the self-signed certificate; it disables certificate trust verification.

If the site is unavailable, inspect `make ps` and the container logs. More diagnostic commands are in [DEV_DOC.md](DEV_DOC.md).

## Data persistence

WordPress website files and MariaDB database files are stored in two Docker **named volumes**, normally named `srcs_wordpress_data` and `srcs_mariadb_data`. With the required Docker daemon configuration, their data lives under `/home/dsemenov/data/docker/volumes/` on the VM.

~~~bash
docker volume ls
docker volume inspect srcs_wordpress_data
docker volume inspect srcs_mariadb_data
~~~

Stopping or recreating containers with `make stop` / `make down` and `make` should preserve the data. To confirm persistence, edit a WordPress page, reboot the VM, start the project and check the edit again. Avoid deleting volumes or modifying their files while services are running.

