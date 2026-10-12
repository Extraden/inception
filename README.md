*This project has been created as part of the 42 curriculum by dsemenov.*

# Inception

## Description

Inception is a system-administration project from the 42 curriculum. It deploys a small WordPress infrastructure **inside a Linux virtual machine** using Docker Compose.

The project builds its own images (rather than using preconfigured service images) from `debian:bookworm`. The three services run in separate containers:

| Service | Purpose | Network endpoint |
| --- | --- | --- |
| **NGINX** | Only public entry point; terminates HTTPS (TLS 1.2 / 1.3) | Host port **443** |
| **WordPress + PHP-FPM** | Runs WordPress via PHP-FPM; installs/configures WordPress with WP-CLI | Internal port **9000** |
| **MariaDB** | Stores WordPress data | Internal port **3306** |

Request flow:

~~~text
Browser -- HTTPS :443 --> NGINX -- FastCGI :9000 --> WordPress/PHP-FPM
                                                   |
                                                   +-- SQL :3306 --> MariaDB
~~~

The containers communicate through the dedicated `inception` bridge network. Only NGINX publishes a host port. The NGINX and WordPress containers share the website-files named volume; the NGINX mount is read-only. MariaDB has its own named volume. Both volumes survive container recreation.

The project's hostname is `dsemenov.42.fr`, normally mapped to the VM's local IP through `/etc/hosts`. The NGINX certificate is self-signed, so browsers can display a trust warning.

### Directory layout

~~~text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── .env                         # local, git-ignored; not committed
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/setup.sh
        └── mariadb/
            ├── Dockerfile
            ├── conf/99-inception.cnf
            └── tools/setup.sh
~~~

Each service has a Dockerfile and uses an explicit local image tag (`nginx:inception`, `wordpress:inception`, and `mariadb:inception`). Their image names match the Compose service names.

## Instructions

**Prerequisites:** a Linux VM with Docker Engine, the Docker Compose plugin, Make and Git. See [DEV_DOC.md](DEV_DOC.md) for the complete first-time setup, including the mandatory host storage layout.

1. Clone this repository into the VM.
2. Configure Docker's `data-root` as `/home/dsemenov/data/docker` **before creating project volumes**. Our project uses regular Docker **named volumes**, without bind-mount driver options; setting the Docker data root makes their mountpoints reside under `/home/dsemenov/data`. This daemon configuration is outside the Git repository and must be applied to the evaluation VM.
3. Create `srcs/.env` locally and populate all required variables. Never commit credentials. Consult [DEV_DOC.md](DEV_DOC.md) for the variable list and setup procedure.
4. Map `dsemenov.42.fr` to the VM's IP in the relevant machine's `/etc/hosts`.
5. From the repository root, run:

~~~bash
make                 # build and launch all services
make ps              # inspect status
make logs            # follow service logs; Ctrl+C to stop viewing
make stop            # stop existing containers
make start           # restart stopped containers
make down            # remove project containers/networks; preserve named volumes
make up              # build/start/recreate as needed
~~~

Visit `https://dsemenov.42.fr` to view WordPress, or `https://dsemenov.42.fr/wp-admin` for the administration panel. Plain HTTP (port 80) is intentionally **not** published.

The `make` target runs `docker compose up -d --build`. The `.env` file is read by Compose for variable interpolation; the service-specific `environment` sections pass values to containers **at creation time**, not into their images.

For end-user guidance, see [USER_DOC.md](USER_DOC.md). For development, troubleshooting, data layout, and clean-room setup, see [DEV_DOC.md](DEV_DOC.md).

## Design decisions and comparisons

### Virtual machines vs Docker

A VM virtualizes hardware and runs a full guest operating system with its own kernel. Docker containers share the host kernel and isolate processes and filesystems, making them lighter and faster to create. Inception uses **both**: Docker runs inside a Debian VM, while each required service lives in a separate container.

### Docker secrets vs environment variables

Environment variables are convenient for application configuration, but secrets supplied this way can be visible in container metadata (`docker inspect`) to users with Docker access. Docker secrets are a safer alternative for sensitive credentials, where supported by applications. **This implementation uses a local git-ignored `srcs/.env` and Compose `environment` variables; it does not claim to implement Docker secrets.** Never commit actual passwords.

### Docker network vs host network

The user-defined bridge network provides container-to-container communication and service-name resolution (for example, `wordpress` connects to `mariadb`). Host networking would place containers directly on the VM's network stack, weakening network separation; it is not used here.

### Docker named volumes vs bind mounts

A named volume is managed by Docker and persists independently of container lifecycle. A bind mount directly maps an explicitly chosen host directory to a container path. This project uses two regular **named volumes** without `driver_opts`/`o: bind`. Docker's host-level `data-root` is configured to place these named volumes beneath `/home/dsemenov/data/docker/volumes`.

## Resources

- [Inception subject and evaluation guidelines](https://projects.intra.42.fr/projects/inception) (42 Intra; login may be required)
- [Docker Engine documentation](https://docs.docker.com/engine/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Docker Compose environment variables](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker daemon configuration](https://docs.docker.com/engine/daemon/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.com/docs/)
- [WP-CLI documentation](https://wp-cli.org/)

### Use of AI

AI assistance was used as a learning and review tool: explaining image/container/volume lifecycles, `ENTRYPOINT` and `CMD`, Compose variable interpolation, discussing MariaDB bootstrap initialization, interpreting logs, and drafting documentation. Configuration changes were reviewed and tested manually, including the service stack, WordPress administration and editing, a MariaDB initialization test, and volume persistence. AI output is not treated as a substitute for understanding or peer evaluation.

