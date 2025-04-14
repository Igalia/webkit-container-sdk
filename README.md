## WebKit Container SDK

Welcome to the WebKit Container SDK, the all-in-one SDK for WebKit GTK/WPE port development.

It provides a fully-equipped container image ready for WebKit development
as well as scripts to run the image using `podman`.

Once you entered the container, you can navigate to a WebKit checkout
and compile using `./Tools/Scripts/build-webkit [--gtk|--wpe]`, as usual.

There is extra documentation in the [**docs**](https://github.com/Igalia/webkit-container-sdk/tree/main/docs)
subdirectory for further information the SDK provides but the guide below will cover common usage.

### Quickstart guide

1. Integrate the SDK with your shell environment.

Add the following to your shell configuration file (e.g. `~/.bashrc`, `~/.zprofile`, ...)
to ensure that the `${WKDEV_SDK}` environment variable points to the correct location
of your `webkit-container-sdk` Git checkout. It also extends the `${PATH}` to make the `wkdev-*` scripts
provided by this repository accessible without having to specify full paths in the shell.

```sh
source /absolute/path/to/your/Git/checkout/of/webkit-container-sdk/register-sdk-on-host.sh
```

Launch a new shell, or `source` your shell configuration files, to verify `${WKDEV_SDK}`
now works as intended -- pointing to your `webkit-container-sdk` checkout.

2. Create a new **wkdev** container for WebKit development

Execute the following command on your host system:

```sh
wkdev-create --create-home
```

This will create a container named **wkdev** by default or a custom one with `--name`
and it will create a new home directory for the SDK in `${HOME}/wkdev-home` by default
or a custom one with `--home`.

Within the container, the `${HOME}` directory is not equal to the host `${HOME}` directory:
`${HOME}/wkdev-home` (from host) is bind-mounted into the container as `/home/${USER}`.
This avoids pollution of files in your host `${HOME}` directory and for convenience
it's still exposed in the container, as `${HOST_HOME}`.

NOTE: `wkdev-create` will auto-detect the whole environment: X11, Wayland, PulseAudio, etc.
and eventually needs **root** permissions on the *host system* to perform first-time-run-only
initializations (such as allowing GPU profiling, by modifying `root`-owned config files, etc.)

3. Enter the new **wkdev** container

Execute the following command on your host system:

```
wkdev-enter --name wkdev
```

After a few seconds you enter the container shell.

4. Verify host system integration is working properly

You may optionally run the test script in the container, which tests various workloads:

```sh
wkdev-test-host-integration
```

5. Compile WPE WebKit

```sh
cd "${HOST_HOME}/path/to/your/WebKit/checkout"
./Tools/Scripts/build-webkit --wpe --release
```

To run tests / execute MiniBrowser, try;

```sh
./Tools/Scripts/run-webkit-tests --wpe --release fast/css # Full tests take a long time
./Tools/Scripts/run-minibrowser --wpe https://browserbench.org/MotionMark1.2/
```

You should expect at least 2 GB of RAM usage per core during the build.
If you have less RAM available, consider limiting the number of cores by setting the `NUMBER_OF_PROCESSORS` environment variable when executing `build-webkit`.

6. READY!


### Update guide

You should check, once in a while, if there is a new upstream version of the `wkdev-sdk` image available.

1. Use the `wkdev-update` tool.

Run `wkdev-update` and following the instructions to selectively update the base images of your local
containers. under the hood it deleted the old containers and re-creates them using the new base image
and your previous settings. **NOTE: Any changes to the container filesystem will VANISH.**. Modifications
to e.g. `/etc` config files in the container, manually installed packages, etc. will disappear. Only the
container home directory will stay untouched.

2. READY!


### Firstrun script

Since you will be regularly re-creating containers there is support for automatically running a script
after each container is created. You can do this by making a `.wkdev-firstrun` script in the directory
you specify as your SDK home (`${HOME}/wkdev-home` by default). This script runs as your user but has
permissions to use `sudo` for tasks such as installing packages. An example script:

```bash
#!/usr/bin/env bash
# This example is a bash script but it can be any executable file.

# Install extra applications like your favorite editor.
sudo apt-get install --yes micro

# The hostname is set to the name of the container so you could
# for example have a specific one where you always work on a library.
if [[ "$(hostname -s)" == "wkdev-foo" ]]; then
    jhbuild --no-interact build glib
fi
```
