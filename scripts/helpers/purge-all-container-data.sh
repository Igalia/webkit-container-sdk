#!/bin/bash -x
podman system reset
podman container prune -f
podman container ls -a
podman image prune -af
podman image ls -a
podman volume prune -f
podman volume ls
