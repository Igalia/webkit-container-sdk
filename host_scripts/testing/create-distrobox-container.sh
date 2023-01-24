#!/usr/bin/bash -x
CONTAINER_HOME_DIRECTORY=${1}

# Get rid of existing 'wkdev' containers, if present.
$(distrobox list | awk 'BEGIN { FS = "|" }; { print $2; }' | grep -q wkdev) && distrobox rm -f wkdev

# Create new distrobox container named 'wkdev'.
distrobox create --name wkdev --image docker.io/nikolaszimmermann/wkdev-sdk:latest --home ${CONTAINER_HOME_DIRECTORY}
