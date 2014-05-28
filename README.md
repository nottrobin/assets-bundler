Assets bundler
===

Scripts for deploying the assets server cluster.

Usage
---

``` bash
make it so
```

or:

``` bash
make juju-bundle &  # Start juju instances in the background
export SERVER_TGZ_URL=`make --silent SERVER_TGZ_URL`  # upload server build to swift and get URL
export FRONTEND_TGZ_URL=`make --silent FRONTEND_TGZ_URL`  # upload frontend build to swift build and get URL
make charms-config.yaml  # Create charms config with swift settings and build URLs
make apply-charms-config  # Apply the config to the juju instances
```
