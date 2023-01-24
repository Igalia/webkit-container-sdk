#!/usr/bin/env bash
THIS_FILE=$(basename ${0})
/wkdev-sdk/build-wkdev-dependencies.sh "$(basename $(echo "${0}" | sed -e "s#${THIS_FILE}##"))"
