SHELL := /bin/bash

# timestamp := $(shell date +%s)
timestamp := $(shell echo '1401268528')

publish:
	$(MAKE) clean  # Delete old files

	$(MAKE) juju-bundle  # Start juju instances

	$(MAKE) config  # Create charm config file

	$(MAKE) apply-charms-config  # Apply config to charms

# Setup juju bundle
# ===

juju-bundle:
	juju-deployer -c assets-bundle.yaml

# Configure
# ===
config:
	SERVER_TGZ_URL=$(shell $(MAKE) --silent SERVER_TGZ_URL) \
	FRONTEND_TGZ_URL=$(shell $(MAKE) --silent FRONTEND_TGZ_URL) \
	$(MAKE) charms-config.yaml  # Create config file

	# Give the container read access
	swift post -r .r:* charm-assets

charms-config.yaml:
	# First check swift credentials
	if [[ '$(SERVER_TGZ_URL)' == '' ]]; then echo "SERVER_TGZ_URL not found - check your OS swift settings"; exit 1; fi
	if [[ '$(FRONTEND_TGZ_URL)' == '' ]]; then echo "FRONTEND_TGZ_URL not found - check your OS swift settings"; exit 1; fi
	if [[ '$(OS_AUTH_URL)' == '' ]]; then echo "OS_AUTH_URL not found - check your OS swift settings"; exit 1; fi
	if [[ '$(OS_USERNAME)' == '' ]]; then echo "OS_USERNAME not found - check your OS swift settings"; exit 1; fi
	if [[ '$(OS_PASSWORD)' == '' ]]; then echo "OS_PASSWORD not found - check your OS swift settings"; exit 1; fi
	if [[ '$(OS_TENANT_NAME)' == '' ]]; then echo "OS_TENANT_NAME not found - check your OS swift settings"; exit 1; fi

	cp templates/charms-config.yaml charms-config.yaml

	sed -i 's!{{server-url}}!$(SERVER_TGZ_URL)!' charms-config.yaml
	sed -i 's!{{frontend-url}}!$(FRONTEND_TGZ_URL)!' charms-config.yaml
	sed -i 's!{{swift_auth}}!$(OS_AUTH_URL)!' charms-config.yaml
	sed -i 's!{{swift_username}}!$(OS_USERNAME)!' charms-config.yaml
	sed -i 's!{{swift_password}}!$(OS_PASSWORD)!' charms-config.yaml
	sed -i 's!{{swift_tenant}}!$(OS_TENANT_NAME)!' charms-config.yaml

apply-charms-config:
	juju set assets-server --config charms-config.yaml
	juju set assets-frontend --config charms-config.yaml

# Assets server
# ===

SERVER_TGZ_URL:
	$(MAKE) assets-server-build.tar.gz
	$(eval tgz_filename := $(shell swift upload charm-assets --object-name assets-server-build.$(timestamp).tar.gz assets-server-build.tar.gz))  # Upload the zip to swift
	echo $(shell swift stat -v charm-assets $(tgz_filename) | grep -o 'http.*')

assets-server-build.tar.gz:
	$(MAKE) assets-server-repo

	$(MAKE) assets-server/update-pip-cache

	tar --exclude-vcs -czf assets-server-build.tar.gz assets-server

assets-server-repo:
	-bzr branch lp:assets-server assets-server
	cd assets-server && bzr pull

assets-server/update-pip-cache:
	mkdir -p assets-server/pip-cache
	pip install --upgrade --download assets-server/pip-cache -r assets-server/requirements.txt


# Assets frontend
# ===

FRONTEND_TGZ_URL:
	$(MAKE) assets-frontend-build.tar.gz
	$(eval tgz_filename := $(shell swift upload charm-assets --object-name assets-frontend-build.$(timestamp).tar.gz assets-frontend-build.tar.gz))  # Upload the zip to swift
	echo $(shell swift stat -v charm-assets $(tgz_filename) | grep -o 'http.*')

assets-frontend-build.tar.gz:
	$(MAKE) assets-frontend-repo

	$(MAKE) assets-frontend/update-pip-cache

	tar --exclude-vcs -czf assets-frontend-build.tar.gz assets-frontend

assets-frontend-repo:
	-bzr branch lp:assets-frontend assets-frontend
	cd assets-frontend && bzr pull

assets-frontend/update-pip-cache:
	mkdir -p assets-frontend/pip-cache
	pip install --upgrade --download assets-frontend/pip-cache -r assets-frontend/requirements.txt


# Clean up created files
# ===
clean:
	rm -f charms-config.yaml assets-server-build.tar.gz assets-frontend-build.tar.gz

# Aliases
# ===
it:
	# And so

so: publish
