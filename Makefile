.DEFAULT_GOAL := help

ifneq (,$(wildcard ./.env))
	include ./.env
	export
endif

COMPOSE        = docker compose
ENV_FILE       = .env
CONFIG_FOLDER  = ./config
DYNAMIC_FILE   = $(CONFIG_FOLDER)/dynamic.yaml
TRAEFIK_FILE   = $(CONFIG_FOLDER)/traefik.yaml

.PHONY: setup up down restart logs ps pull help

setup: ## 🛠️ Generate environment and config files from templates
	@if [ ! -f $(ENV_FILE) ]; then \
		if [ -f $(ENV_TEMPLATE) ]; then \
			echo "==> Generating $(ENV_FILE) from template"; \
			cp $(ENV_TEMPLATE) $(ENV_FILE); \
			echo "==> $(ENV_FILE) generated"; \
			echo "⚠️ Please edit $(ENV_FILE) before starting the containers"; \
			echo "⚠️ Run 'make up' to start the containers"; \
		else \
			echo "⚠️ No $(ENV_TEMPLATE) found, skipping .env generation"; \
		fi \
	else \
		echo "==> $(ENV_FILE) already exists, skipping"; \
	fi

	@echo "==> Creating folder $(CONFIG_FOLDER)"
	@mkdir -p $(CONFIG_FOLDER)

	@if [ ! -f $(TRAEFIK_FILE) ]; then \
		echo "==> Generating traefik.yaml from template"; \
		cp templates/traefik.yaml.template $(TRAEFIK_FILE); \
	else \
		echo "==> $(TRAEFIK_FILE) already exists, skipping"; \
	fi

	@if [ ! -f $(DYNAMIC_FILE) ]; then \
		echo "==> Generating dynamic.yaml from template"; \
		cp templates/dynamic.yaml.template $(DYNAMIC_FILE); \
	else \
		echo "==> $(DYNAMIC_FILE) already exists, skipping"; \
	fi

up: setup ## 🚀 Start containers
	@$(COMPOSE) --env-file $(ENV_FILE) up -d --remove-orphans

down: ## 🛑 Stop containers
	@$(COMPOSE) --env-file $(ENV_FILE) down

restart: down up ## 🔄 Restart containers

logs: ## 📜 Show logs in real time
	@$(COMPOSE) --env-file $(ENV_FILE) logs -f

ps: ## 📊 Show container status
	@$(COMPOSE) --env-file $(ENV_FILE) ps

pull: ## 📦 Pull the latest images
	@$(COMPOSE) pull

help: ## 🤔 Show this help message
	@echo "\033[1;33mAvailable commands:\033[0m"
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
