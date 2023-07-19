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
permissions to use `sudo` to install packages for example.


### Building third-party libraries

As the container is a normal Ubuntu installation there are many ways to install custom libraries
however we have a solution to make this easier. [JHBuild](https://gnome.pages.gitlab.gnome.org/jhbuild/index.html)
is a tool that automates downloading, building, and installing projects and is provided in the SDK.

#### Hacking on glib with JHBuild

1. Build glib master### Firstrun script

Since you will be regularly re-creating containers there is support for automatically running a script
after each container is created. You can do this by making a `.wkdev-firstrun` script in the directory
you specify as your SDK home (`${HOME}/wkdev-home` by default). This script runs as your user but has
permissions to use `sudo` to install packages for example.
ib

All of the sources are located in `~/checkout`.

```sh
cd ~/checkout/glib
# Modify as you please
jhbuild make
```

Note that `jhbuild make` only works in the checkout directory. If you have sources
in another location you can make a symlink matching the module name.

You can remove your modified version with `jhbuild uninstall glib` though do note
that some JHBuild modules such as GStreamer are included by default and should not
be uninstalled.

#### Hacking on other libraries in JHBuild

We provide a small list of projects that can be easily hacked on. You can view
the projects JHBuild knows about with `jhbuild list --all-modules`. The process
is identical for all of these projects.

If you want to add a new project you can make [a moduleset file](https://gnome.pages.gitlab.gnome.org/jhbuild/moduleset-syntax.html)
to use the same workflow. Examples can be found in `/jhbuild/webkit-sdk-deps.modules`
(our default modules) and  `/jhbuild/jhbuild/modulesets/`. You can then build a
custom moduleset with `jhbuild -m ~/myproject.modules build myproject` for example.

It is also possible to directly build any project like so:

```sh
jhbuild shell
# For CMake
cmake -DCMAKE_INSTALL_PREFIX=$JHBUILD_PREFIX -DCMAKE_INSTALL_LIBDIR=$JHBUILD_LIBDIR ...
# For Meson
meson setup --prefix=$JHBUILD_PREFIX --libdir=$JHBUILD_LIBDIR ...
```
