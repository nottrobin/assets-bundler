SHELL := /bin/bash

CONTAINER_NAME=charm-assets

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
	rm -f charms-config.yaml

	SERVER_TGZ_URL=$(shell $(MAKE) --no-print-directory SERVER_TGZ_URL | tail -n 1) \
	FRONTEND_TGZ_URL=$(shell $(MAKE) --no-print-directory FRONTEND_TGZ_URL | tail -n 1) \
	$(MAKE) charms-config.yaml  # Create config file

	# Give the container read access
	swift post -r .r:* $(CONTAINER_NAME)

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
	$(MAKE) assets-server-build

	$(eval BUILD_FILENAME=assets-server-build.$(shell sha1sum assets-server-build.tar.gz | grep -o '^\w*').tar.gz)

	cp -n assets-server-build.tar.gz $(BUILD_FILENAME)

	if [[ ! $$(swift stat $(CONTAINER_NAME) $(BUILD_FILENAME)) ]]; then swift upload $(CONTAINER_NAME) $(BUILD_FILENAME); fi

	# Upload the zip to swift
	swift stat -v $(CONTAINER_NAME) $(BUILD_FILENAME) | grep -o 'http.*'

assets-server-build:
	rm -f assets-server-build.tar.gz

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
	$(MAKE) assets-frontend-build

	$(eval BUILD_FILENAME=assets-frontend-build.$(shell sha1sum assets-frontend-build.tar.gz | grep -o '^\w*').tar.gz)

	cp -n assets-frontend-build.tar.gz assets-frontend-build.$(BUILD_SHA1).tar.gz

	if [[ ! $$(swift stat $(CONTAINER_NAME) $(BUILD_FILENAME)) ]]; then swift upload $(CONTAINER_NAME) $(BUILD_FILENAME); fi

	# Upload the zip to swift
	swift stat -v $(CONTAINER_NAME) $(BUILD_FILENAME) | grep -o 'http.*'

assets-frontend-build:
	rm -f assets-frontend-build.tar.gz

	$(MAKE) assets-frontend-repo

	$(MAKE) assets-frontend/update-pip-cache

	tar --exclude-vcs -czf assets-frontend-build.tar.gz assets-frontend

assets-frontend-repo:
	-bzr branch lp:assets-frontend assets-frontend
	cd assets-frontend && bzr pull

assets-frontend/update-pip-cache:
	mkdir -p assets-frontend/pip-cache
	pip install --upgrade --download assets-frontend/pip-cache -r assets-frontend/requirements.txt


# Clean up all created files
# ===
clean:
	rm -f charms-config.yaml assets-server-build*.tar.gz assets-frontend-build*.tar.gz assets-server assets-frontend

# Aliases
# ===
it:
	# And so

so: publish
