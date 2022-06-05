SHELL = /bin/bash

include .env.dist
-include .env

UID := $(shell id -u)
GID := $(shell id -g)
CWD := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DOCKER_COMPOSE := docker-compose
EXEC := $(DOCKER_COMPOSE) exec webserver
EXEC_AS_ROOT := $(DOCKER_COMPOSE) exec -u 0 webserver
EXEC_ON_DATABASE := $(DOCKER_COMPOSE) exec database
EXEC_SCRIPT := $(DOCKER_COMPOSE) exec scripter

MAKE := make

MEDIA_WIKI_VERSION_DIRECTORY := $(shell echo $(MEDIA_WIKI_VERSION) | sed -E "s/^(.*)\.[^.]+$$/\1/")

CURRENT_DATE := $(shell date -u +"%Y-%m-%dT%H-%M-%SZ")

PLOP := $(shell cat src/LocalSettings.php | grep "$wgSitename =")
WIKI_NAME := $(shell cat src/LocalSettings.php | grep "$wgSitename =" | sed -E 's/.*"([^"]+)".*/\1/')
DATABASE_NAME := $(shell cat src/LocalSettings.php | grep "$wgDBname =" | sed -E 's/.*"([^"]+)".*/\1/')
BACKUPS_DIRECTORY := .run/backups
BACKUP_NAME := $(WIKI_NAME)-$(CURRENT_DATE)-backup
BACKUP_DIRECTORY := $(BACKUPS_DIRECTORY)/$(BACKUP_NAME)
RESTORATION_NAME := $(shell test -r $(BACKUPS_DIRECTORY)/backup.tar.gz && tar -tzf $(BACKUPS_DIRECTORY)/backup.tar.gz | grep backup/$$ | sed -E 's/(.*)\/$$/\1/')
RESTORATION_DIRECTORY := $(BACKUPS_DIRECTORY)/$(RESTORATION_NAME)

.ONESHELL:
.PHONY: start stop restart log log-watch setup exec exec-root save restore

start: stop
	$(DOCKER_COMPOSE) build --build-arg UID=$(UID) --build-arg GID=$(GID)
	$(DOCKER_COMPOSE) up -d --no-build --remove-orphans

stop:
	$(DOCKER_COMPOSE) stop

restart:
	$(DOCKER_COMPOSE) restart
	
setup:
	@test -r .env || cp .env.dist .env
	@echo "MediaWiki distribution downloading ($(MEDIA_WIKI_VERSION))..."
	@mkdir -p .run src
	@if [ ! -f .run/media-wiki.tar.gz ]; then\
		wget -O .run/media-wiki.tar.gz https://releases.wikimedia.org/mediawiki/$(MEDIA_WIKI_VERSION_DIRECTORY)/mediawiki-$(MEDIA_WIKI_VERSION).tar.gz;\
		tar -xzf .run/media-wiki.tar.gz -C src;\
		mv src/mediawiki-$(MEDIA_WIKI_VERSION)/* src;\
		rm -r src/mediawiki-$(MEDIA_WIKI_VERSION);\
	fi
	$(MAKE) start
	$(EXEC_SCRIPT) npm install

log:
	$(DOCKER_COMPOSE) log

log-watch:
	$(DOCKER_COMPOSE) log-watch

exec:
	$(EXEC) bash

exec-root:
	$(EXEC_AS_ROOT) bash

save:
	@echo '--- Backup ---'
	@mkdir -p $(BACKUP_DIRECTORY)
	@echo 'Database dumping ($(BACKUP_NAME))...'
	$(EXEC_ON_DATABASE) mysqldump -u root -p$(DATABASE_ROOT_PASSWORD) --databases $(DATABASE_NAME) --skip-comments > $(BACKUP_DIRECTORY)/dump.sql
	@echo 'Settings retrieving...'
	cp src/LocalSettings.php $(BACKUP_DIRECTORY)/LocalSettings.php
	@cd $(BACKUPS_DIRECTORY)
	@echo 'Backup compressing ($(BACKUP_NAME).tar.gz)...'
	tar -czvf $(BACKUP_NAME).tar.gz $(BACKUP_NAME)
	@cd $(CWD)
	rm -rf $(BACKUP_DIRECTORY)
	$(EXEC_SCRIPT) node bin/save

restore: save
	@echo '--- Restoration ---'
	@cd $(BACKUPS_DIRECTORY)
	@echo 'Backup extracting (backup.tar.gz)...'
	tar -xzvf backup.tar.gz
	@cd $(CWD)
	@echo 'Database restoring ($(RESTORATION_NAME))...'
	$(EXEC_ON_DATABASE) /bin/bash -c 'mysql -u root -p$(DATABASE_ROOT_PASSWORD) < /var/backups/$(RESTORATION_NAME)/dump.sql'
	@echo 'Settings overwriting...'
	cp -f $(RESTORATION_DIRECTORY)/LocalSettings.php src/LocalSettings
