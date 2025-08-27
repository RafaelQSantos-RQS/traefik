.DEFAULT_GOAL := help

ifneq (,$(wildcard ./.env))
	include ./.env
	export
endif

COMPOSE        = docker compose
ENV_FILE       = .env
ENV_TEMPLATE   = .env.template
CONFIG_FOLDER  = ./config
DYNAMIC_FILE   = $(CONFIG_FOLDER)/dynamic.yaml
TRAEFIK_FILE   = $(CONFIG_FOLDER)/traefik.yaml

.PHONY: setup up down restart logs status pull help clean

setup: ## 🛠️ Generate environment and config files from templates
	@if [ ! -f $(ENV_FILE) ]; then \
		if [ -f $(ENV_TEMPLATE) ]; then \
			echo "==> Generating $(ENV_FILE) from template"; \
			cp $(ENV_TEMPLATE) $(ENV_FILE); \
			HOSTNAME_CMD=$$(hostname -s); \
			sed -i "s|TRAEFIK_HOST=<HOSTNAME>.|TRAEFIK_HOST=$${HOSTNAME_CMD}.|" $(ENV_FILE); \
			echo "⚠️ Please edit $(ENV_FILE) and run 'make setup' again"; \
			exit 1; \
		else \
			echo "❌ No $(ENV_TEMPLATE) found. Cannot continue."; \
			exit 1; \
		fi \
	else \
		echo "==> $(ENV_FILE) already exists"; \
	fi

	@echo "==> Creating folder $(CONFIG_FOLDER)"
	@mkdir -p $(CONFIG_FOLDER)

	@if [ ! -f $(TRAEFIK_FILE) ]; then \
		echo "==> Generating traefik.yaml from template"; \
		cp templates/traefik.yaml.template $(TRAEFIK_FILE); \
	else \
		echo "==> $(TRAEFIK_FILE) already exists, skipping"; \
	fi

	@echo "==> Generating dynamic.yaml from template with hashed credentials"
	@if [ -z "$$DASH_USER" ] || [ -z "$$DASH_PASS" ]; then \
		echo "❌ DASH_USER or DASH_PASS not set in $(ENV_FILE). Please configure and run 'make setup' again."; \
		exit 1; \
	fi
	@DASH_PASS_HASH=$$(htpasswd -nbm $$DASH_USER $$DASH_PASS | cut -d":" -f2); \
		DASH_USER=$$DASH_USER DASH_PASS_HASH=$$DASH_PASS_HASH envsubst < templates/dynamic.yaml.template > $(DYNAMIC_FILE); \
		echo "✅ dynamic.yaml generated at $(DYNAMIC_FILE)";

	@echo "✅ Environment and config files generated at $(ENV_FILE), $(TRAEFIK_FILE) and $(DYNAMIC_FILE)"

up: setup ## 🚀 Start containers
	@$(COMPOSE) --env-file $(ENV_FILE) up -d --remove-orphans

down: ## 🛑 Stop containers
	@$(COMPOSE) --env-file $(ENV_FILE) down

restart: down up ## 🔄 Restart containers

logs: ## 📜 Show logs in real time
	@$(COMPOSE) --env-file $(ENV_FILE) logs -f

status: ## 📊 Show container status
	@$(COMPOSE) --env-file $(ENV_FILE) ps

pull: ## 📦 Pull the latest images
	@$(COMPOSE) pull

help: ## 🤔 Show this help message
	@echo "\033[1;33mAvailable commands:\033[0m"
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
