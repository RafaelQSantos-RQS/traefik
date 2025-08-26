.DEFAULT_GOAL := help

ifneq (,$(wildcard ./.env))
	include ./.env
	export
endif

ENV_FILE=.env
ENV_FILE_TEMPLATE=.env.template

# Environment variables
EXTERNAL_DOCKER_NETWORK ?= web
LE_DIR ?= ./letsencrypt
ACME_FILE ?= ./letsencrypt/acme.json

COMPOSE = docker compose

.PHONY: setup run help stop restart pull status validate

setup: ## Prepare environment for docker-compose
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "Creating environment file $(ENV_FILE) from template $(ENV_FILE_TEMPLATE)" ; \
		cp $(ENV_FILE_TEMPLATE) $(ENV_FILE) ; \
		echo "Please edit $(ENV_FILE) and run 'make setup' again" ; \
		exit 1 ; \
	else \
		echo "Environment file $(ENV_FILE) already exists" ; \
		echo "Nothing will be done..." ; \
	fi

	@echo "Creating docker network $(EXTERNAL_DOCKER_NETWORK)"
	@docker network inspect $$EXTERNAL_DOCKER_NETWORK >/dev/null 2>&1 || docker network create $$EXTERNAL_DOCKER_NETWORK
	@echo "Docker network $(EXTERNAL_DOCKER_NETWORK) is ready"

	@echo "Creating folder $(LE_DIR) and file $(ACME_FILE) for letsencrypt"
	@mkdir -p $$LE_DIR
	@touch $$ACME_FILE
	@chmod 600 $$ACME_FILE
	@echo "Folder $(LE_DIR) and file $(ACME_FILE) are ready"

validate: ## Validates environment and docker-compose configuration
	@echo "==> Validating environment variables..."
	@if [ -z "$$EXTERNAL_DOCKER_NETWORK" ]; then \
		echo "Error: EXTERNAL_DOCKER_NETWORK is not set in .env"; \
		exit 1; \
	fi
	@if [ -z "$$LE_DIR" ]; then \
		echo "Error: LE_DIR is not set in .env"; \
		exit 1; \
	fi
	@if [ -z "$$ACME_FILE" ]; then \
		echo "Error: ACME_FILE is not set in .env"; \
		exit 1; \
	fi
	@echo "Environment variables look good."

	@echo "==> Validating Docker network..."
	-docker network inspect $$EXTERNAL_DOCKER_NETWORK >/dev/null 2>&1 || echo "Network $$EXTERNAL_DOCKER_NETWORK will be created during setup."

	@echo "==> Validating docker-compose file..."
	@$(COMPOSE) --env-file $(ENV_FILE) config >/dev/null
	@if [ $$? -ne 0 ]; then \
		echo "Error: docker-compose.yml validation failed"; \
		exit 1; \
	fi
	@echo "docker-compose.yml is valid."

run: validate ## Starts the containers (runs setup and validate first)
	@echo "==> Starting services..."
	@$(COMPOSE) --env-file $(ENV_FILE) up -d --remove-orphans

stop: ## Stops and removes containers.
	@echo "==> Stopping services..."
	@$(COMPOSE) --env-file $(ENV_FILE) down

restart: stop run ## Restarts the stack.

pull: ## Updates the Docker images.
	@echo "==> Pulling the latest images..."
	@$(COMPOSE) pull

status: ## Shows the status of the containers.
	@echo "==> Showing container status..."
	@$(COMPOSE) ps

logs: ## Shows the logs of all containers in real-time.
	@echo "==> Showing logs (all services)..."
	@$(COMPOSE) logs -f

sync: ## Synchronize local repository with remote (force, overwrites local changes)
	@echo "==> Synchronizing local repository with remote..."
	@if [ "$$FORCE" = "1" ]; then \
		echo "FORCE mode: skipping confirmation..."; \
	else \
		read -p "WARNING: This will destroy local changes. Continue? (y/N): " choice; \
		if [ "$$choice" != "y" ]; then echo "Aborted."; exit 1; fi; \
	fi
	@git fetch origin
	@git reset --hard origin/$(shell git rev-parse --abbrev-ref HEAD)
	@git clean -fd
	@echo "Repository is now synchronized with remote."

help: ## Shows this help message.
	@echo "\033[1;33mAvailable commands:\033[0m"
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
	| awk 'BEGIN {FS = ":.*?## "}; \
	{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

%: # Generic target to catch unknown commands.
	@echo "\033[31mError: Target '$(@)' not found.\033[0m"