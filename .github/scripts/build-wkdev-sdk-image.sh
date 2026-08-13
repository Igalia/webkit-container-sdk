#!/bin/bash
# Single source of truth for building the wkdev-sdk image. Used by the image
# build workflow and by the storage maintenance cache-warming rebuild: both
# MUST build the exact same way, otherwise the layers produced by the nightly
# rebuild would not be reusable as cache by the PR builds.

set -euo pipefail

VERSION="${1:?Usage: $0 <wkdev-sdk-version> <image-tag> <arch>}"
TAG="${2:?Usage: $0 <wkdev-sdk-version> <image-tag> <arch>}"
ARCH="${3:?Usage: $0 <wkdev-sdk-version> <image-tag> <arch>}"

podman build --jobs "$(nproc)" --build-context scripts=./scripts \
  --build-arg WKDEV_SDK_VERSION="${VERSION}" \
  -t "${TAG}" --arch="${ARCH}" images/wkdev_sdk
podman image list
