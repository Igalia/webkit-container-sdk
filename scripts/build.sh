#!/bin/bash -x
NUMBER_OF_CPUS=$(cat /proc/cpuinfo | grep "processor\s*\:\s*" | wc -l)
podman build --build-arg NUMBER_OF_PARALLEL_BUILDS=${NUMBER_OF_CPUS} -t docker.io/nikolaszimmermann/wkdev-sdk:latest ${@} .
