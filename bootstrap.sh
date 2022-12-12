#!/bin/bash

# Use podman directly to build image & deploy on docker.io
scripts/build.sh
scripts/deploy.sh

# Test creation of quick toolbx containers
scripts/create-toolbox.sh

# Test creation of full-fledged distrobox containers
scripts/helpers/create-home-directory.sh /tmp/wkdev-bootstrap-home
scripts/create-distrobox.sh /tmp/wkdev-bootstrap-home
