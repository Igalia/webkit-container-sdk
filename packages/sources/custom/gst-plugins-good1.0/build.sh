#!/usr/bin/env bash
THIS_FILE=$(basename ${0})
${WKDEV_SDK}/scripts/helpers/build-wkdev-dependencies.sh "$(basename $(echo "${0}" | sed -e "s#${THIS_FILE}##"))"
