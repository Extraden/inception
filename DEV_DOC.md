# Inception — Developer documentation

## Overview and prerequisites

This repository builds three separate images from `debian:bookworm` and runs them using Docker Compose:

| Service | Image | Role |
| --- | --- | --- |
| `nginx` | `nginx:inception` | HTTPS entry point on host port 443, FastCGI reverse proxy |
| `wordpress` | `wordpress:inception` | WordPress via PHP-FPM on port 9000 (internal only) |
| `mariadb` | `mariadb:inception` | MariaDB on port 3306 (internal only) |

The tested environment is a Debian 13 VM with Docker Engine, Compose plugin, Git, Make, and `curl`. Other compatible Linux VMs may work, but the project must be evaluated inside a VM. Graphical desktop and SSH are optional.

**Reproduction requirement:** the two named volumes must live under `/home/dsemenov/data` on the VM. This setup achieves it by setting Docker's daemon-level `data-root` to `/home/dsemenov/data/docker`, *not* by configuring bind mounts in Compose. The `data-root` setting is **outside the repository** and must be applied to a new evaluation VM.

## 1. Install dependencies

On a new Debian VM:

~~~bash
sudo apt update
sudo apt install -y git make curl ca-certificates
~~~

Install Docker Engine and the Compose plugin using the [official Debian installation instructions](https://docs.docker.com/engine/install/debian/). One supported approach uses Docker's official APT repository:

~~~bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker compose version
~~~

Docker commands can be run with `sudo`. For a development-only VM, optionally add your account to the `docker` group (`sudo usermod -aG docker "$USER"`) and **log out and back in**. Membership in this group grants effectively root-level access to the host; use it only when appropriate.

## 2. Configure Docker storage before creating volumes

On a **fresh** development/evaluation VM, while Docker is not in use:

~~~bash
sudo systemctl stop docker.service docker.socket
sudo mkdir -p /home/dsemenov/data/docker
sudo chmod 700 /home/dsemenov/data/docker
~~~

Inspect any existing `/etc/docker/daemon.json` first. If it does **not** exist and this is a new Docker installation, create it:

~~~bash
sudo mkdir -p /etc/docker
printf '%s\n' '{"data-root":"/home/dsemenov/data/docker"}' |
  sudo tee /etc/docker/daemon.json
sudo systemctl start docker.service
docker info --format '{{.DockerRootDir}}'
~~~

The expected result is `/home/dsemenov/data/docker`. If the daemon configuration file already exists, **merge** the `data-root` property into the existing JSON instead of replacing the entire file.

If Docker already has images, containers, or volumes in `/var/lib/docker`, changing `data-root` does **not** automatically migrate that existing data. Back it up and plan a separate migration; do not assume existing resources are still available after the change. On a different 42 login, adjust both the `data-root` and domain consistently.

With the project's Compose configuration, two standard named volumes will then have mountpoints such as:

~~~text
/home/dsemenov/data/docker/volumes/srcs_mariadb_data/_data
/home/dsemenov/data/docker/volumes/srcs_wordpress_data/_data
~~~

There are **no** `driver_opts`, `o: bind`, or bind mounts for these two volumes.

## 3. Clone and configure the repository

~~~bash
cd ~
git clone https://github.com/Extraden/inception.git
cd inception
~~~

Create `srcs/.env` locally (this file is ignored by Git). Supply your **own** credentials instead of treating the placeholders below as real passwords:

~~~dotenv
DOMAIN_NAME=https://dsemenov.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=REPLACE_WITH_LOCAL_DB_PASSWORD
MYSQL_ROOT_PASSWORD=REPLACE_WITH_LOCAL_ROOT_PASSWORD

WP_TITLE=Inception
WP_ADMIN_USER=dsemenov
WP_ADMIN_PASSWORD=REPLACE_WITH_LOCAL_WP_ADMIN_PASSWORD
WP_ADMIN_EMAIL=owner@example.com

WP_USER=wp_author
WP_USER_PASSWORD=REPLACE_WITH_LOCAL_WP_AUTHOR_PASSWORD
WP_USER_EMAIL=author@example.com
~~~

Then protect the file:

~~~bash
chmod 600 srcs/.env
git check-ignore srcs/.env
~~~

Never commit actual credentials. In particular, the **value** of `WP_ADMIN_USER` must not contain `admin` or `administrator` in any case. The value of `DOMAIN_NAME` contains `https://` because WordPress setup uses it as the site's full URL.

The Compose file interpolates `${VARIABLE}` values from `.env` and passes values to containers through each service's `environment` section. These values are not baked into the Docker images; however, they are visible to users with permission to inspect the container configuration. Running `docker compose config` can also print them, so do not share its full output.

## 4. Configure local hostname resolution

When browsing **inside** this VM, configure `/etc/hosts` so the requested domain resolves to loopback:

~~~text
127.0.0.1 dsemenov.42.fr
~~~

Edit the file as root, avoiding duplicate entries. Verify:

~~~bash
getent hosts dsemenov.42.fr
~~~

When browsing from a separate host, the domain must instead resolve **on that host** to the VM's reachable IP, and its networking/port forwarding must permit HTTPS port 443. A loopback entry on the host would point to the host itself, not the VM.

## 5. Build and launch

From the **repository root**:

~~~bash
make          # default = make up = docker compose up -d --build
make ps
make logs     # Ctrl+C to stop following logs
~~~

The Makefile calls:

~~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
~~~

Compose uses the build contexts under `srcs/requirements/` to build the three locally tagged images, creates the bridge network and two named volumes, and creates/starts the three containers.

The MariaDB `setup.sh` initializes a fresh database with `mariadb-install-db` and `mariadbd --bootstrap` (no background server). It ends with `exec "$@"` to replace the script with the main `mariadbd` process. The WordPress startup script waits for MariaDB, uses WP-CLI for first-time setup, creates the administrator and author users, then `exec`s PHP-FPM in foreground mode. If their persistent data already exists, initial setup is skipped or checked.

The only published port in Compose is `443:443` for NGINX. Port 80 is not published. NGINX permits only TLS 1.2 and TLS 1.3; its certificate is self-signed.

## 6. Container, network, image and volume management

~~~bash
make build       # build images only
make up          # build/start/reconcile services
make stop        # stop existing containers
make start       # start existing containers
make restart     # restart existing containers; does not reload .env changes
make down        # remove containers and project network; keep named volumes
make re          # down then up (preserves named volumes)
make ps          # show running containers
make logs        # live logs
~~~

For more detailed inspection:

~~~bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps -a
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs --tail=100
docker images
docker network ls
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
~~~

The two volume inspections should show `Mountpoint` paths inside `/home/dsemenov/data/docker/volumes` and `Options: null`, not `o: bind`.

**Do not use `docker compose down -v` for routine operation:** it removes the project's persistent named volumes. Data deletion is irreversible without a backup.

If the Dockerfile or copied scripts change, run `make up` to rebuild and apply updated images. If `srcs/.env` changes, recreate affected containers with `make up`; `make restart` will not update existing container environments. Changing a password in `.env` does not retroactively update an account stored in MariaDB/WordPress.

## 7. Verify and troubleshoot

~~~bash
make ps
curl -kI https://dsemenov.42.fr
curl -I --connect-timeout 3 http://dsemenov.42.fr
docker exec mariadb mariadb -u root -p -e 'SHOW DATABASES;'
~~~

The HTTPS request should succeed; a connection refusal on port 80 is expected if no other local service listens there. The MariaDB command prompts for the **database root** password. Do not put real passwords directly in commands that might be saved in shell history.

For TLS verification:

~~~bash
openssl s_client -connect dsemenov.42.fr:443 -servername dsemenov.42.fr -tls1_2 </dev/null
~~~

Use a browser to confirm the site is already installed (no WordPress installer), log into `/wp-admin`, edit a page, and confirm the new text appears. Check the second WordPress user and database tables as required by the evaluation.

If containers fail, check `make ps` and logs; note that `depends_on` controls creation/start order, not full service readiness. The WordPress setup script waits for the database.

## 8. Persistence, backup and reboot test

Both named volumes survive `make down` and VM reboot. To check persistence:

1. Change a WordPress page through `/wp-admin`.
2. Record the visible change.
3. Run `make down` and reboot the VM.
4. Run `make` after reboot.
5. Confirm the website, administrator panel, database and edited page are still functional.

To make a consistent file-level backup, first stop the project (`make down`), then archive the directories inside the two named volumes. Do not copy live MariaDB data files while the database is writing to them. Keep backups outside the Docker volume directories, with restricted permissions. Restore the files, preserving owner UID/GID and permissions, **before** starting services.

## 9. Evaluation/defense checks

Be ready to demonstrate:

- Explanation of Docker, Compose, images vs containers, networks and VM comparison.
- Images built locally from the required base image; names match services.
- No host networking, `links`, infinite-loop keepalive tricks or background processes in entrypoint scripts.
- Only HTTPS port 443 exposed; NGINX with TLS 1.2 / 1.3.
- Working WordPress and two users; administrator username without `admin`/`administrator`.
- MariaDB data and two standard named volumes whose mountpoints are under `/home/dsemenov/data`.
- Preserved website edits after a VM restart.
- A small configuration change (for example, changing a service's listening port) followed by rebuild/restart and a working test.

For a reproducible peer evaluation, use a fresh clone and recreate the local `.env` and VM-level Docker `data-root` configuration. Neither credentials nor Docker daemon configuration are stored in Git.

## References

- [Docker Engine install (Debian)](https://docs.docker.com/engine/install/debian/)
- [Docker daemon configuration](https://docs.docker.com/engine/daemon/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [MariaDB documentation](https://mariadb.com/docs/)
- [WP-CLI](https://wp-cli.org/)

