In `Containerfile` we copy `jhbuildrc` and our modulesets to the image.

Then we run:

```
export JHBUILD_RUN_AS_ROOT=1 WKDEV_IN_IMAGE_BUILD=1
jhbuild --no-interact build
```

The build state is cached in `/var/tmp/jhbuild` during image generation
but not included in the final image.

If you want to hack on this, simply modify the moduleset and rebuild
the SDK.

Tip: Enable verbose mode when building. Example:
  wkdev-sdk-bakery --verbose --mode build

If there is some issue building the jhbuild and you want to debug it
then the easiest way is to start the container on the step previous
to executing the deploy script and run it manually.

For example, if you have this:

  STEP 41/46: WORKDIR /jhbuild
  --> 2fabea45a33f
  STEP 42/46: RUN git clone https://gitlab.gnome.org/GNOME/jhbuild.git ...

Then you can debug step 27 with:

  $ podman run -it --rm 2fabea45a33f /bin/bash
  root@2fabea45a33f:~# env JHBUILD_RUN_AS_ROOT=1 WKDEV_IN_IMAGE_BUILD=1 jhbuild build
