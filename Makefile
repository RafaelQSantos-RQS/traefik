.DEFAULT_GOAL := help

ifneq (,$(wildcard ./.env))
	include ./.env
	export
endif

COMPOSE        = docker compose
ENV_FILE       = .env
ENV_TEMPLATE   = .env.template
CONFIG_FOLDER  = ./config
EXTERNAL_DOCKER_NETWORK ?= web
DYNAMIC_FILE   = $(CONFIG_FOLDER)/dynamic.yaml
TRAEFIK_FILE   = $(CONFIG_FOLDER)/traefik.yaml

.PHONY: setup up down restart logs status pull help clean _create-network-if-not-exists sync add-user update-user delete-user list-users deploy-stack remove-stack stack-status stack-logs

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

	@if [ ! -f $(CONFIG_FOLDER)/credentials ]; then \
		echo "==> Generating credentials file"; \
		if [ -z "$$DASH_USER" ] || [ -z "$$DASH_PASS" ]; then \
			echo "❌ DASH_USER or DASH_PASS not set in $(ENV_FILE). Please configure and run 'make setup' again."; \
			exit 1; \
		fi; \
		htpasswd -nbm $$DASH_USER $$DASH_PASS > $(CONFIG_FOLDER)/credentials; \
		echo "✅ New credentials file generated at $(CONFIG_FOLDER)/credentials"; \
	else \
		echo "==> $(CONFIG_FOLDER)/credentials already exists, skipping"; \
	fi

	@$(MAKE) _create-network-if-not-exists

	@echo "✅ Environment and config files generated at $(ENV_FILE), $(TRAEFIK_FILE) and $(DYNAMIC_FILE)"

_create-network-if-not-exists:
	@echo "==> Checking for network $(EXTERNAL_DOCKER_NETWORK)..."
	@docker network inspect $(EXTERNAL_DOCKER_NETWORK) >/dev/null 2>&1 || \
		(echo "==> Network $(EXTERNAL_DOCKER_NETWORK) not found. Creating..." && docker network create $(EXTERNAL_DOCKER_NETWORK))
	@echo "✅ Network $(EXTERNAL_DOCKER_NETWORK) is ready."

sync: ## 🔄 Syncs the local code with the remote 'main' branch (discards local changes!).
	@echo "==> Syncing with the remote repository (origin/main)..."
	@git fetch origin
	@git reset --hard origin/main
	@echo "Sync completed. Directory is clean and up-to-date."

up: ## 🚀 Start containers
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

add-user: ## ➕ Add a new user to credentials file
	@if [ -z "$(USERNAME)" ] || [ -z "$(PASS)" ]; then \
		echo "❌ Usage: make add-user USERNAME=username PASS=password"; \
		exit 1; \
	fi
	@echo "==> Adding user $(USERNAME) to credentials file"
	@htpasswd -nbm $(USERNAME) $(PASS) | tr -d '\n' >> $(CONFIG_FOLDER)/credentials
	@echo "" >> $(CONFIG_FOLDER)/credentials
	@echo "✅ User $(USERNAME) added successfully"
	@echo "⚠️ Restart Traefik to apply changes: make restart"

update-user: ## 🔄 Update password for an existing user
	@if [ -z "$(USERNAME)" ] || [ -z "$(PASS)" ]; then \
		echo "❌ Usage: make update-user USERNAME=username PASS=newpassword"; \
		exit 1; \
	fi
	@if ! grep -q "^$(USERNAME):" $(CONFIG_FOLDER)/credentials; then \
		echo "❌ User $(USERNAME) not found"; \
		exit 1; \
	fi
	@echo "==> Updating password for user $(USERNAME)"
	@sed -i "/^$(USERNAME):/d" $(CONFIG_FOLDER)/credentials
	@htpasswd -nbm $(USERNAME) $(PASS) | tr -d '\n' >> $(CONFIG_FOLDER)/credentials
	@echo "" >> $(CONFIG_FOLDER)/credentials
	@echo "✅ Password for user $(USERNAME) updated successfully"
	@echo "⚠️ Restart Traefik to apply changes: make restart"

delete-user: ## 🗑️ Delete a user from credentials file
	@if [ -z "$(USERNAME)" ]; then \
		echo "❌ Usage: make delete-user USERNAME=username"; \
		exit 1; \
	fi
	@if ! grep -q "^$(USERNAME):" $(CONFIG_FOLDER)/credentials; then \
		echo "❌ User $(USERNAME) not found"; \
		exit 1; \
	fi
	@echo "==> Deleting user $(USERNAME)"
	@sed -i "/^$(USERNAME):/d" $(CONFIG_FOLDER)/credentials
	@echo "✅ User $(USERNAME) deleted successfully"
	@echo "⚠️ Restart Traefik to apply changes: make restart"

list-users: ## 👥 List all users in credentials file
	@if [ ! -f $(CONFIG_FOLDER)/credentials ]; then \
		echo "❌ Credentials file not found"; \
		exit 1; \
	fi
	@echo "==> Users in credentials file:"
	@cut -d: -f1 $(CONFIG_FOLDER)/credentials | grep -v '^$$' | sed 's/^/  - /'

deploy-stack: ## 🐳 Deploy Traefik to Docker Swarm
	@echo "==> Deploying Traefik to Swarm..."
	@docker stack deploy -c docker-stack.yml traefik
	@echo "✅ Traefik deployed to Swarm"

remove-stack: ## 🗑️ Remove Traefik from Docker Swarm
	@echo "==> Removing Traefik from Swarm..."
	@docker stack rm traefik
	@echo "✅ Traefik removed from Swarm"

stack-status: ## 📊 Show Traefik stack status
	@docker stack ps traefik

stack-logs: ## 📜 Show Traefik Swarm logs
	@docker stack logs -f traefik

help: ## 🤔 Show this help message
	@echo ""
	@echo "Traefik Management"
	@echo "=================="
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort \
	| sed 's/:.*## /: /' \
	| awk 'BEGIN {FS = ": "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo ""
