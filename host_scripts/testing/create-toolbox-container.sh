#!/usr/bin/bash -x

# Get rid of existing 'wkdev-quick' containers, if present.
$(toolbox list --containers | awk '{print $2}' | grep -q wkdev-quick) && toolbox rm -f wkdev-quick

# Create new toolbx container named 'wkdev-quick'.
toolbox create -i docker.io/nikolaszimmermann/wkdev-sdk:latest wkdev-quick
