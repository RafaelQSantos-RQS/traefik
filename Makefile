.DEFAULT_GOAL := help

ifneq (,$(wildcard ./.env))
	include ./.env
	export
endif

COMPOSE                 = docker compose
ENV_FILE                = .env
ENV_TEMPLATE            = .env.template
CONFIG_FOLDER           = ./config
CERTS_FOLDER            = ./certs
EXTERNAL_DOCKER_NETWORK ?= web
DYNAMIC_FILE            = $(CONFIG_FOLDER)/dynamic.yaml
TRAEFIK_FILE            = $(CONFIG_FOLDER)/traefik.yaml
SWARM_DYNAMIC_FILE     = $(CONFIG_FOLDER)/dynamic-swarm.yaml
SWARM_TRAEFIK_FILE     = $(CONFIG_FOLDER)/traefik-swarm.yaml
CREDENTIALS_SECRET      = TRAEFIK_CREDENTIALS
TRAEFIK_STATIC_CONFIG   = TRAEFIK_STATIC
TRAEFIK_DYNAMIC_CONFIG  = TRAEFIK_DYNAMIC

LOG = @echo "[$$(date '+%Y-%m-%d %H:%M:%S')]"

.PHONY: help setup compose-setup swarm-setup compose-up compose-down compose-restart compose-logs compose-status compose-pull \
	add-user update-user delete-user list-users \
	swarm-create-configs swarm-create-secrets swarm-update-configs swarm-update-secrets \
	swarm-remove-configs swarm-remove-secrets swarm-check-configs swarm-check-secrets \
	swarm-deploy swarm-remove swarm-status swarm-logs sync

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

	$(LOG) "Creating folder $(CONFIG_FOLDER)"
	@mkdir -p $(CONFIG_FOLDER)

	@if [ ! -f $(TRAEFIK_FILE) ]; then \
		$(LOG) "Generating traefik.yaml from template"; \
		cp templates/traefik.yaml.template $(TRAEFIK_FILE); \
	else \
		$(LOG) "$(TRAEFIK_FILE) already exists, skipping"; \
	fi

	@if [ ! -f $(CONFIG_FOLDER)/credentials ]; then \
		$(LOG) "Generating credentials file"; \
		if [ -z "$$DASH_USER" ] || [ -z "$$DASH_PASS" ]; then \
			$(LOG) "DASH_USER or DASH_PASS not set in $(ENV_FILE). Please configure and run 'make setup' again."; \
			exit 1; \
		fi; \
		htpasswd -nbm $$DASH_USER $$DASH_PASS > $(CONFIG_FOLDER)/credentials; \
		$(LOG) "New credentials file generated at $(CONFIG_FOLDER)/credentials"; \
	else \
		$(LOG) "$(CONFIG_FOLDER)/credentials already exists, skipping"; \
	fi

	@$(MAKE) _create-network-if-not-exists

	$(LOG) "Environment and config files generated"

compose-setup: ## ⚙️ Generate Docker Compose config files (traefik.yaml + dynamic.yaml)
	$(LOG) "Creating folder $(CONFIG_FOLDER)"
	@mkdir -p $(CONFIG_FOLDER)

	@if [ ! -f $(TRAEFIK_FILE) ]; then \
		$(LOG) "Generating traefik.yaml from template"; \
		cp templates/traefik.yaml.template $(TRAEFIK_FILE); \
	else \
		$(LOG) "$(TRAEFIK_FILE) already exists, skipping"; \
	fi

	@if [ ! -f $(DYNAMIC_FILE) ]; then \
		$(LOG) "Generating dynamic.yaml from template"; \
		cp templates/dynamic.yaml.template $(DYNAMIC_FILE); \
	else \
		$(LOG) "$(DYNAMIC_FILE) already exists, skipping"; \
	fi

	@$(MAKE) _create-network-if-not-exists

	$(LOG) "Docker Compose config files generated"

swarm-setup: ## 🐳 Generate Docker Swarm config files (traefik-swarm.yaml + dynamic-swarm.yaml)
	$(LOG) "Creating folder $(CONFIG_FOLDER)"
	@mkdir -p $(CONFIG_FOLDER)

	@if [ ! -f $(SWARM_TRAEFIK_FILE) ]; then \
		$(LOG) "Generating traefik-swarm.yaml from template"; \
		cp templates/traefik-swarm.yaml.template $(SWARM_TRAEFIK_FILE); \
	else \
		$(LOG) "$(SWARM_TRAEFIK_FILE) already exists, skipping"; \
	fi

	@if [ ! -f $(SWARM_DYNAMIC_FILE) ]; then \
		$(LOG) "Generating dynamic-swarm.yaml from template"; \
		cp templates/dynamic-swarm.yaml.template $(SWARM_DYNAMIC_FILE); \
	else \
		$(LOG) "$(SWARM_DYNAMIC_FILE) already exists, skipping"; \
	fi

	$(LOG) "Docker Swarm config files generated"

_create-network-if-not-exists:
	$(LOG) "Checking for network $(EXTERNAL_DOCKER_NETWORK)..."
	@docker network inspect $(EXTERNAL_DOCKER_NETWORK) >/dev/null 2>&1 || \
		($(LOG) "Network $(EXTERNAL_DOCKER_NETWORK) not found. Creating..." && docker network create --attachable $(EXTERNAL_DOCKER_NETWORK))
	$(LOG) "Network $(EXTERNAL_DOCKER_NETWORK) is ready."

add-user: ## ➕ Add a new user to credentials file
	@if [ -z "$(USERNAME)" ] || [ -z "$(PASS)" ]; then \
		$(LOG) "Usage: make add-user USERNAME=username PASS=password"; \
		exit 1; \
	fi
	$(LOG) "Adding user $(USERNAME) to credentials file"
	@htpasswd -nbm $(USERNAME) $(PASS) | tr -d '\n' >> $(CONFIG_FOLDER)/credentials
	@echo "" >> $(CONFIG_FOLDER)/credentials
	$(LOG) "User $(USERNAME) added successfully"
	$(LOG) "Restart Traefik to apply changes: make compose-restart"

update-user: ## 🔄 Update password for an existing user
	@if [ -z "$(USERNAME)" ] || [ -z "$(PASS)" ]; then \
		$(LOG) "Usage: make update-user USERNAME=username PASS=newpassword"; \
		exit 1; \
	fi
	@if ! grep -q "^$(USERNAME):" $(CONFIG_FOLDER)/credentials; then \
		$(LOG) "User $(USERNAME) not found"; \
		exit 1; \
	fi
	$(LOG) "Updating password for user $(USERNAME)"
	@sed -i "/^$(USERNAME):/d" $(CONFIG_FOLDER)/credentials
	@htpasswd -nbm $(USERNAME) $(PASS) | tr -d '\n' >> $(CONFIG_FOLDER)/credentials
	@echo "" >> $(CONFIG_FOLDER)/credentials
	$(LOG) "Password for user $(USERNAME) updated successfully"
	$(LOG) "Restart Traefik to apply changes: make compose-restart"

delete-user: ## 🗑️ Delete a user from credentials file
	@if [ -z "$(USERNAME)" ]; then \
		$(LOG) "Usage: make delete-user USERNAME=username"; \
		exit 1; \
	fi
	@if ! grep -q "^$(USERNAME):" $(CONFIG_FOLDER)/credentials; then \
		$(LOG) "User $(USERNAME) not found"; \
		exit 1; \
	fi
	$(LOG) "Deleting user $(USERNAME)"
	@sed -i "/^$(USERNAME):/d" $(CONFIG_FOLDER)/credentials
	$(LOG) "User $(USERNAME) deleted successfully"
	$(LOG) "Restart Traefik to apply changes: make compose-restart"

list-users: ## 👥 List all users in credentials file
	@if [ ! -f $(CONFIG_FOLDER)/credentials ]; then \
		$(LOG) "Credentials file not found"; \
		exit 1; \
	fi
	$(LOG) "Users in credentials file:"
	@cut -d: -f1 $(CONFIG_FOLDER)/credentials | grep -v '^$$' | sed 's/^/  - /'

compose-up: ## 🚀 Start containers (Docker Compose)
	$(LOG) "Starting containers..."
	@$(COMPOSE) --env-file $(ENV_FILE) up -d --remove-orphans
	$(LOG) "Containers started"

compose-down: ## 🛑 Stop containers (Docker Compose)
	$(LOG) "Stopping containers..."
	@$(COMPOSE) --env-file $(ENV_FILE) down
	$(LOG) "Containers stopped"

compose-restart: compose-down compose-up ## 🔄 Restart containers (Docker Compose)

compose-logs: ## 📜 Show logs in real time (Docker Compose)
	@$(COMPOSE) --env-file $(ENV_FILE) logs -f

compose-status: ## 📊 Show container status (Docker Compose)
	@$(COMPOSE) --env-file $(ENV_FILE) ps

compose-pull: ## 📦 Pull the latest images (Docker Compose)
	$(LOG) "Pulling latest images..."
	@$(COMPOSE) pull
	$(LOG) "Images pulled"

swarm-create-configs: ## 🐳 Create Docker Swarm configs for Traefik YAML files
	$(LOG) "Creating Docker Swarm configs..."
	@docker config rm $(TRAEFIK_STATIC_CONFIG) 2>/dev/null || true
	@docker config rm $(TRAEFIK_DYNAMIC_CONFIG) 2>/dev/null || true
	@docker config create $(TRAEFIK_STATIC_CONFIG) $(SWARM_TRAEFIK_FILE) >/dev/null 2>&1
	@docker config create $(TRAEFIK_DYNAMIC_CONFIG) $(SWARM_DYNAMIC_FILE) >/dev/null 2>&1
	$(LOG) "Traefik configs created successfully"

swarm-create-secrets: ## 🔐 Create all Docker Swarm secrets (credentials + certs)
	$(LOG) "Creating Docker Swarm secrets..."
	@docker secret rm $(CREDENTIALS_SECRET) >/dev/null 2>&1 || true
	@docker secret create $(CREDENTIALS_SECRET) $(CONFIG_FOLDER)/credentials >/dev/null 2>&1
	$(LOG) "Credentials secret created"
	@docker secret rm TRAEFIK_SENAI_CIMATEC_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_SENAI_CIMATEC_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_SENAI_CIMATEC_CRT certs/senaicimatec_com_br/senaicimatec_com_br.pem >/dev/null 2>&1
	@docker secret create TRAEFIK_SENAI_CIMATEC_KEY certs/senaicimatec_com_br/senaicimatec_com_br.key >/dev/null 2>&1
	$(LOG) "Senaicimatec certs secrets created"
	@docker secret rm TRAEFIK_JBTH_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_JBTH_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_JBTH_CRT certs/jbth/full_chain_jbth.crt >/dev/null 2>&1
	@docker secret create TRAEFIK_JBTH_KEY certs/jbth/jbth.com.br.key >/dev/null 2>&1
	$(LOG) "JBTH certs secrets created"
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT certs/universidadesenaicimatec_edu_br/fullchain_universidadesenaicimatec.edu.brv2.pem >/dev/null 2>&1
	@docker secret create TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY certs/universidadesenaicimatec_edu_br/universidadesenaicimatec.edu.brv2.key >/dev/null 2>&1
	$(LOG) "Uni secrets created"
	$(LOG) "All secrets created successfully"

swarm-update-configs: ## 🔄 Update existing Docker Swarm configs
	$(LOG) "Updating Docker Swarm configs..."
	@docker config rm $(TRAEFIK_STATIC_CONFIG) 2>/dev/null || true
	@docker config rm $(TRAEFIK_DYNAMIC_CONFIG) 2>/dev/null || true
	@docker config create $(TRAEFIK_STATIC_CONFIG) $(SWARM_TRAEFIK_FILE) >/dev/null 2>&1
	@docker config create $(TRAEFIK_DYNAMIC_CONFIG) $(SWARM_DYNAMIC_FILE) >/dev/null 2>&1
	$(LOG) "Traefik configs updated successfully"
	$(LOG) "Restart Traefik to apply changes: make swarm-deploy"

swarm-update-secrets: ## 🔄 Update all Docker Swarm secrets (credentials + certs)
	$(LOG) "Updating Docker Swarm secrets..."
	@docker secret rm $(CREDENTIALS_SECRET) >/dev/null 2>&1 || true
	@docker secret create $(CREDENTIALS_SECRET) $(CONFIG_FOLDER)/credentials >/dev/null 2>&1
	$(LOG) "Credentials secret updated"
	@docker secret rm TRAEFIK_SENAI_CIMATEC_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_SENAI_CIMATEC_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_SENAI_CIMATEC_CRT certs/senaicimatec_com_br/senaicimatec_com_br.pem >/dev/null 2>&1
	@docker secret create TRAEFIK_SENAI_CIMATEC_KEY certs/senaicimatec_com_br/senaicimatec_com_br.key >/dev/null 2>&1
	$(LOG) "Senaicimatec certs secrets updated"
	@docker secret rm TRAEFIK_JBTH_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_JBTH_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_JBTH_CRT certs/jbth/full_chain_jbth.crt >/dev/null 2>&1
	@docker secret create TRAEFIK_JBTH_KEY certs/jbth/jbth.com.br.key >/dev/null 2>&1
	$(LOG) "JBTH certs secrets updated"
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT >/dev/null 2>&1 || true
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY >/dev/null 2>&1 || true
	@docker secret create TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT certs/universidadesenaicimatec_edu_br/fullchain_universidadesenaicimatec.edu.brv2.pem >/dev/null 2>&1
	@docker secret create TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY certs/universidadesenaicimatec_edu_br/universidadesenaicimatec.edu.brv2.key >/dev/null 2>&1
	$(LOG) "Universidadecerts secrets updated"
	$(LOG) "All secrets updated successfully"
	$(LOG) "Restart Traefik to apply changes: make swarm-deploy"

swarm-remove-configs: ## 🗑️ Remove Docker Swarm configs
	$(LOG) "Removing Docker Swarm configs..."
	@docker config rm $(TRAEFIK_STATIC_CONFIG) 2>/dev/null || true
	@docker config rm $(TRAEFIK_DYNAMIC_CONFIG) 2>/dev/null || true
	$(LOG) "Traefik configs removed"

swarm-remove-secrets: ## 🗑️ Remove all Docker Swarm secrets
	$(LOG) "Removing Docker Swarm secrets..."
	@docker secret rm $(CREDENTIALS_SECRET) 2>/dev/null || true
	@docker secret rm TRAEFIK_SENAI_CIMATEC_KEY 2>/dev/null || true
	@docker secret rm TRAEFIK_JBTH_CRT 2>/dev/null || true
	@docker secret rm TRAEFIK_JBTH_KEY 2>/dev/null || true
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT 2>/dev/null || true
	@docker secret rm TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY 2>/dev/null || true
	$(LOG) "All secrets removed"

swarm-check-configs: ## 🔍 Check if Docker Swarm configs exist
	@echo "[$$(date '+%Y-%m-%d %H:%M:%S')] Checking Docker Swarm configs..."
	@if docker config ls | grep -q $(TRAEFIK_STATIC_CONFIG); then \
		echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(TRAEFIK_STATIC_CONFIG) exists"; \
	else \
		echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(TRAEFIK_STATIC_CONFIG) does not exist"; \
	fi
	@if docker config ls | grep -q $(TRAEFIK_DYNAMIC_CONFIG); then \
		echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(TRAEFIK_DYNAMIC_CONFIG) exists"; \
	else \
		echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $(TRAEFIK_DYNAMIC_CONFIG) does not exist"; \
	fi

swarm-check-secrets: ## 🔍 Check if Docker Swarm secrets exist
	@echo "[$$(date '+%Y-%m-%d %H:%M:%S')] Checking Docker Swarm secrets..."
	@for secret in $(CREDENTIALS_SECRET) TRAEFIK_SENAI_CIMATEC_CRT TRAEFIK_SENAI_CIMATEC_KEY TRAEFIK_JBTH_CRT TRAEFIK_JBTH_KEY TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_CRT TRAEFIK_UNIVERSIDADE_SENAI_CIMATEC_KEY; do \
		if docker secret ls | grep -q $$secret; then \
			echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $$secret exists"; \
		else \
			echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $$secret does not exist"; \
		fi \
	done

swarm-deploy: swarm-check-configs swarm-check-secrets ## 🐳 Deploy Traefik to Docker Swarm
	$(LOG) "Deploying Traefik to Swarm..."
	@export $$(cat $(ENV_FILE) | xargs) && docker stack deploy -c docker-stack.yml traefik
	$(LOG) "Traefik deployed to Swarm"

swarm-remove: ## 🗑️ Remove Traefik from Docker Swarm
	$(LOG) "Removing Traefik from Swarm..."
	@docker stack rm traefik
	$(LOG) "Traefik removed from Swarm"

swarm-status: ## 📊 Show Traefik stack status
	@docker stack ps traefik

swarm-logs: ## 📜 Show Traefik Swarm logs
	@docker stack logs -f traefik

sync: ## 🔄 Syncs the local code with the remote 'main' branch (discards local changes!).
	$(LOG) "Syncing with the remote repository (origin/main)..."
	@git fetch origin
	@git reset --hard origin/main
	$(LOG) "Sync completed. Directory is clean and up-to-date."

help: ## 🤔 Show this help message
	@echo ""
	@echo "  ╔══════════════════════════════════════════════════════════════════╗"
	@echo "  ║                     TRAEFIK MANAGEMENT                           ║"
	@echo "  ╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  📋  GENERAL"
	@echo "  ────────────────────────────────────────────────────────────────────"
	@echo "    make setup             Generate environment and all config files"
	@echo "    make compose-setup     Generate Docker Compose config files only"
	@echo "    make swarm-setup       Generate Docker Swarm config files only"
	@echo "    make sync              Sync with remote 'main' branch"
	@echo ""
	@echo "  👥  USERS"
	@echo "  ────────────────────────────────────────────────────────────────────"
	@echo "    make add-user              Add a new user to credentials"
	@echo "    make update-user           Update password for existing user"
	@echo "    make delete-user           Delete a user from credentials"
	@echo "    make list-users            List all users in credentials"
	@echo ""
	@echo "  🐳  DOCKER COMPOSE"
	@echo "  ────────────────────────────────────────────────────────────────────"
	@echo "    make compose-up            Start containers"
	@echo "    make compose-down          Stop containers"
	@echo "    make compose-restart       Restart containers"
	@echo "    make compose-logs          Show logs in real time"
	@echo "    make compose-status        Show container status"
	@echo "    make compose-pull          Pull the latest images"
	@echo ""
	@echo "  ☁️  DOCKER SWARM"
	@echo "  ────────────────────────────────────────────────────────────────────"
	@echo "    make swarm-deploy          Deploy Traefik to Swarm"
	@echo "    make swarm-remove          Remove Traefik from Swarm"
	@echo "    make swarm-status          Show stack status"
	@echo "    make swarm-logs            Show Swarm logs"
	@echo "    make swarm-create-configs  Create configs (traefik.yaml/dynamic.yaml)"
	@echo "    make swarm-create-secrets  Create all secrets (credentials + certs)"
	@echo "    make swarm-update-configs  Update existing configs"
	@echo "    make swarm-update-secrets  Update all secrets (credentials + certs)"
	@echo "    make swarm-remove-configs  Remove configs"
	@echo "    make swarm-remove-secrets  Remove all secrets"
	@echo "    make swarm-check-configs  Check if configs exist"
	@echo "    make swarm-check-secrets  Check if secrets exist"
	@echo ""
	@echo "  ────────────────────────────────────────────────────────────────────"
	@echo "  Examples:"
	@echo "    make add-user USERNAME=admin PASS=mypassword"
	@echo "    make update-user USERNAME=admin PASS=newpassword"
	@echo "    make delete-user USERNAME=admin"
	@echo ""
