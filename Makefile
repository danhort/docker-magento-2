SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
PHP_SERVICE := docker-compose exec php sh -c

# Define a static project name that will be prepended to each service name
export COMPOSE_PROJECT_NAME := magento2

# This Makefile is designed to be extended by another Makefile located in your project directory.
# ==> https://github.com/EmakinaFR/docker-magento2/wiki/Makefile

# Create configuration files needed by the environment
SETUP_ENV := $(shell (test -f $(SELF_DIR).env || cp $(SELF_DIR).env.dist $(SELF_DIR).env))
SETUP_SERVER := $(shell (test -f $(SELF_DIR)nginx/servers/custom.conf || touch $(SELF_DIR)nginx/servers/custom.conf))

# Extract environment variables needed by the environment
export DOCKER_PHP_IMAGE := $(shell grep DOCKER_PHP_IMAGE $(SELF_DIR).env | awk -F '=' '{print $$NF}')
export DOCKER_MOUNT_POINT := $(shell grep DOCKER_MOUNT_POINT $(SELF_DIR).env | awk -F '=' '{print $$NF}')

##
## ----------------------------------------------------------------------------
##   Environment
## ----------------------------------------------------------------------------
##

backup: ## Backup the "mysql" volume
	docker run --rm \
		--volumes-from $$(docker-compose ps -q mysql) \
		-v $$(pwd):/backup \
		busybox sh -c "tar cvf /backup/backup.tar /var/lib/mysql"

build: ## Build the environment
	docker-compose build

cache: ## Flush cache stored in Redis
	docker-compose exec redis sh -c "redis-cli -n 1 FLUSHDB"
	docker-compose exec redis sh -c "redis-cli -n 2 FLUSHDB"

composer: ## Install Composer dependencies from the "php" container
	$(PHP_SERVICE) "composer install -o --working-dir=$(PROJECT_PATH)"

logs: ## Follow logs generated by all containers
	docker-compose logs -f --tail=0

logs-full: ## Follow logs generated by all containers from the containers creation
	docker-compose logs -f

nginx: ## Open a terminal in the "nginx" container
	docker-compose exec nginx sh

php: ## Open a terminal in the "php" container
	docker-compose exec php sh

ps: ## List all containers managed by the environment
	docker-compose ps

restore: ## Restore the "mysql" volume
	docker run --rm \
		--volumes-from $$(docker-compose ps -q mysql) \
		-v $$(pwd):/backup \
		busybox sh -c "tar xvf /backup/backup.tar var/lib/mysql/"
	docker-compose restart mysql

start: ## Start the environment
	docker-compose build
	docker-compose up -d --remove-orphans

stats: ## Print real-time statistics about containers ressources usage
	docker stats $(docker ps --format={{.Names}})

stop: ## Stop the environment
	docker-compose stop

yarn: ## Install Composer dependencies from the "php" container
	$(PHP_SERVICE) "yarn install --cwd=$(PROJECT_PATH)"

.PHONY: backup build cache composer logs logs-full nginx php ps restore start stats stop yarn

.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| sed -e 's/^.*Makefile://g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.PHONY: help
