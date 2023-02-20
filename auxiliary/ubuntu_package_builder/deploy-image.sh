#!/usr/bin/bash

# FIXME: Make configurable

# Bash scripting recommendations
set -o errexit # Exit upon command failure
set -o nounset # Warn about unset variables

podman login docker.io
podman push docker.io/nikolaszimmermann/ubuntu-package-builder:22.10
