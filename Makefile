COMPOSE = docker compose -f srcs/docker-compose.yml --env-file srcs/.env

.PHONY: all build up down stop start restart logs ps re

all: up

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

re: down up