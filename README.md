## wkdev-sdk

Welcome to wkdev-sdk, the all-in-one SDK for WebKit GTK/WPE port development.

It provides a fully-equipped container image ready for WebKit development.
We recommend to use **podman** to execute the OCI-compatible container image.

Once you entered the container, you can navigate to a WebKit checkout
and compile using Tools/Scripts/build-webkit --gtk / --wpe, as usual.

Please refer to the documentation in the **docs** subdirectory for further
information on what the SDK provides and how it greatly simplifies WebKit
development and removes a lot of friction, by providing a reproducible,
consistent development/testing environment for all our users/developers.

### Quickstart guide

1. Integrate `wkdev-sdk` with your shell environment.

Add the following to your shell configuration file (e.g. `~/.bashrc`, `~/.zprofile`, ...)
to ensure that the `${WKDEV_SDK}` environment variable points to the correct location
of your `wkdev-sdk` Git checkout. It also extends the `${PATH}` to make the `wkdev-\*` scripts
provided by this repository accessible without having to specifcy full paths in the shell.

```
# wkdev-sdk integration
pushd /absolute/path/to/your/Git/checkout/of/wkdev-sdk &>/dev/null
source ./register-sdk-on-host.sh
popd &>/dev/null
```

Launch a new shell, or `source` your shell configuration files to verify, `${WKDEV_SDK}`
now expects as intented - pointing to your `wkdev-sdk` checkout.

2. Create a new **wkdev** container for WebKit development

Execute the following command on your host system:

```wkdev-create --name wkdev --create-home --home ${HOME}/wkdev-home```

This will create a container named **wkdev**, and transparently maps the current hoser user/ID
into the container. Within the container, the `${HOME}` directtory is not equal to the host
`${HOME}` directory: `${HOME}/wkdev-home` (from host) is bind-mounted into the container as
`/home/hostuser`. This avoids pollution of files in your host `${HOME}` directory -- for
convenience it's still exposed in the container, as `${HOST_HOME}`.

NOTE: `wkdev-create` will auto-detect the whole environment: X11, Wayland, PulseAudio, etc.
and eventually needs **root** permissions on the *host system* to perform first-time-run-only
initializations (such as allowing GPU profiling, by modifying `root`-owned config files, etc.)

3. Enter the new **wkdev** container

Execute the following command on your host system:

```wkdev-enter --name wkdev```

After a few seconds you enter the container shell.

4. Verify host system integration is working properly

Run the test script in the container, which tests various workloads:

```wkdev-test-host-integration```

5. Compile WPE WebKit

```
cd ${HOST_HOME}/path/to/your/WebKit/checkout
git pull
Tools/Scripts/build-webkit --wpe --release --cmakeargs "-DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_THUNDER=OFF"
```

To run tests / execute MiniBrowser, try;

```
Tools/Scripts/run-webkit-tests --wpe --release fast/css # Full tests take a long time
Tools/Scripts/run-minibrowser --wpe https://browserbench.org/MotionMark1.2/
```

6. READY!
