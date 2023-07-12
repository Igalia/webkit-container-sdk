This directory gets copied to the container when building it
from the Containerfile and the script init-install.sh
is executed.

This script takes care of getting the jhbuild code and building
and deploying the libraries from the moduleset defined here.

Finally the build artifacts and sources are cleaned from the image
to save disk space from the final image.

If you want to hack on this, simply modify the moduleset and rebuild
the SDK.

Tip: Enable verbose mode when building. Example:
  wkdev-sdk-bakery --verbose --mode build

If there is some issue building the jhbuild and you want to debug it
then the easiest way is to start the container on the step previous
to executing the deploy script and run it manually.

For example, if you have this:

  STEP 26/35: COPY /jhbuild /root/jhbuild-webkit-sdk
  --> d7b0866719d
  STEP 27/35: RUN /root/jhbuild-webkit-sdk/init-install.sh

Then you can debug step 27 with:

  $ podman run -it --rm d7b0866719d /bin/bash
  root@c2ec0d851de0:~# /root/jhbuild-webkit-sdk/init-install.sh
