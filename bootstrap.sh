#!/usr/bin/bash -x

# 1) Build image using podman
scripts/build.sh
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
    exit ${STATUS}
fi

# 2) Test creation of quick toolbx containers
scripts/create-toolbox.sh
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
    exit ${STATUS}
fi

# 3) Test creation of full-fledged distrobox containers
host_scripts/create-home-directory.sh /tmp/wkdev-bootstrap-home
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
    exit ${STATUS}
fi

scripts/create-distrobox.sh /tmp/wkdev-bootstrap-home
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
    exit ${STATUS}
fi

# 4) Cleanup
rm -Rf /tmp/wkdev-bootstap-home &> /dev/null

# 5) Show instructions how to deploy new SDK image to docker.io
echo ""
echo "Ready. If everything went well, use \"./scripts/deploy.sh\" to push the new SDK image to the registry, once tested!"
