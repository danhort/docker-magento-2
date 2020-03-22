# Define a static project name that will be prepended to each service name
export COMPOSE_PROJECT_NAME := $(shell grep COMPOSE_PROJECT_NAME ${DOCKER_PATH}/docker.env | awk -F '=' '{print $$NF}')

# Extract environment variables needed by the environment
export PROJECT_LOCATION := $(shell echo ${MAKEFILE_DIRECTORY})

# Extract path to the magento directory
export MAGENTO_ROOT := $(shell echo ${MAKEFILE_DIRECTORY})$(shell grep MAGENTO_ROOT ${DOCKER_PATH}/docker.env | awk -F '=' '{print $$NF}')

# Extract php version variable
export PHP_VERSION := $(shell grep PHP_VERSION ${DOCKER_PATH}/docker.env | awk -F '=' '{print $$NF}')

# Extract magneto version variable
export MAGENTO_VERSION := $(shell grep MAGENTO_VERSION ${DOCKER_PATH}/docker.env | awk -F '=' '{print $$NF}')


##    _____             _               __  __                        _
##   |  __ \           | |             |  \/  |                      | |
##   | |  | | ___   ___| | _____ _ __  | \  / | __ _  __ _  ___ _ __ | |_ ___
##   | |  | |/ _ \ / __| |/ / _ \ '__| | |\/| |/ _` |/ _` |/ _ \ '_ \| __/ _ \
##   | |__| | (_) | (__|   <  __/ |    | |  | | (_| | (_| |  __/ | | | || (_) |
##   |_____/ \___/ \___|_|\_\___|_|    |_|  |_|\__,_|\__, |\___|_| |_|\__\___/
##                                                    __/ |
##                                                   |___/

##
## ----------------------------------------------------------------------------
##   Environment
## ----------------------------------------------------------------------------
##

update: ## Update the ops
	cd $(DOCKER_PATH) && git pull origin master

install: ## Install the bash tool
	sudo  sh $(DOCKER_PATH)/bin/install.sh

##
## ----------------------------------------------------------------------------
##   Docker
## ----------------------------------------------------------------------------
##

build: ## Build the environment
	docker-compose build

start: ## Start the environment
	docker-compose build
	docker-compose up -d --remove-orphans

stop: ## Stop the environment
	docker-compose stop

restart: stop start ## Restart the environment

kill: ## kill all the project's docker container
	docker-compose  stop \
	& docker-compose  down -v

ps: ## List all containers managed by the environment
	docker-compose ps

stats: ## Print real-time statistics about containers ressources usage
	docker stats $(docker ps --format={{.Names}})

logs: ## Follow logs generated by all containers
	docker-compose logs -f --tail=0

logs-full: ## Follow logs generated by all containers from the containers creation
	docker-compose logs -f

nginx: ## Open a terminal in the "nginx" container
	docker-compose exec nginx sh

user := www-data
php: ## Open a terminal in the "php" container
	docker-compose exec --user $(user) php sh

mysql: ## Open a terminal in the "mysql" container
	docker-compose exec --user root mysql sh

phpmyadmin: ## Open a terminal in the "phpmyadmin" container
	docker-compose exec --user root phpmyadmin sh

##
## ----------------------------------------------------------------------------
##   Database
## ----------------------------------------------------------------------------
##

# The sed command removes the definer to prevent errors
REMOVE_DEFINER := sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/'
file := backup
db-dump: ## dump the mysql database [file=<file name>], dump specific tables [tables="<table1 table2 ...>"]
	docker-compose exec -T -u root mysql mysqldump -umagento -pmagento magento $(tables) | $(REMOVE_DEFINER) | gzip -c > $(DOCKER_PATH)/mysqldump/$(file).sql.gz

db-import: ## import to mysql database [file=<file name>]
	zcat -f $(DOCKER_PATH)/mysqldump/$(file) | $(REMOVE_DEFINER) | docker-compose exec -T -u root mysql mysql -uroot -pmagento magento

##
## ----------------------------------------------------------------------------
##   Magento
## ----------------------------------------------------------------------------
##

edition := project-community-edition
magento2-install: ## Installs new Magento 2 instance [edition=<magento edition>] [version=<m2-version>]
	docker-compose exec --user www-data php composer create-project --repository-url=https://repo.magento.com/ magento/$(edition): $(version) .

n98: ## n98-magerun2 commands [t="<task>"]
	@docker-compose exec --user www-data php n98 $(t)

magento: ## magento commands [t="<task>"]
	@docker-compose exec --user www-data php bin/magento $(t)

composer: ## composer commands [t="<task>"]
	@docker-compose exec --user www-data php composer $(t)

yarn: ## yarn commands [t="<task>"]
	@docker-compose exec --user www-data php yarn $(t)

clear-assets: ## clear the Magento static assets
	@rm -rf src/pub/static/* \
	& rm -rf src/var/cache/* \
	& rm -rf src/var/composer_home/* \
	& rm -rf src/var/page_cache/* \
	& rm -rf src/var/view_preprocessed/*

flush-redis: ## Flush cache stored in Redis
	docker-compose exec redis sh -c "redis-cli flushall"

cache-watch: ## Run mage2tv cache-clean [t="<task>"]
	docker-compose exec --user root php /root/.composer/vendor/bin/cache-clean.js -d /var/www/html $(t)

##
## ----------------------------------------------------------------------------
##   Links
## ----------------------------------------------------------------------------
##

Magento: ## https://magento.localhost
	@xdg-open https://magento.localhost

Magento-admin: ## https://magento.localhost/admin
	@xdg-open https://magento.localhost/admin

phpMyAdmin: ## http://localhost:8080
	@xdg-open http://localhost:8080

Maildev: ## http://localhost:1080
	@xdg-open http://localhost:1080

.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| sed -e 's/^.*Makefile://g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
