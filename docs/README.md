## Introduction to ``wkdev SDK``

NOTE: This documents covers _using_ the SDK. Creating the images is covered in BUILDING.md.

The ``wkdev SDK`` provides a hassle-free environment to perform WebKit Gtk/WPE development.
It is distributed in form of an **OCI image**, a standardized container format that allows
any OCI-compatible container system, such as **Docker** and **podman**, to run the SDK.
The same image can also be used within the WebKit Early Warning System (EWS) to provide
an environment in which tests can be executed in a reliable & reproducible way.

By utilizing the ``wkdev SDK``, a vanilla Linux installation can be turned into a fully
functional WebKit development / debugging environment within minutes. After the initial
setup procedure, the ``wkdev SDK`` user (hereafter: the **developer**) can either directly
run commands within the **wkdev** container or launch one or more interactive shell
sessions, in which you can compile WebKit / run tests / etc.

To run CLI applications within a container, requires no effort: it works out of the box.
Runing graphical applications, that utilize e.g. [Wayland](https://wayland.freedesktop.org)
for screen presentation, need [D-Bus](https://freedesktop.org/wiki/Software/dbus) to communicate
with other system components, or use [SystemD](https://freedesktop.org/wiki/Software/systemd)
APIs to query network / power / etc. information, require a substantial amount of configuration
to allow the containerized GUI application to integrate seamlessly within the host desktop
environment.

To overcome the tedious setup procedure, wrapper tools were created, such as [toolbx](https://containertoolbx.org)
and [distrobox](https://distrobox.privatedns.org), that greatly simplify the setup procedure.
Therefore we recommend to use any of these wrappers to create and run the ``wkdev SDK`` containers.

**distrobox** and **toolbx** both allow you to run GUI applications out of the box, the former supports
both **Docker** and **podman** as backends, where **toolbx** is tied to **podman** only. Both also support
to share the current host user and its **\$HOME directory** with the container, replacing any other
\$HOME directory that might reside in the OCI container image. **toolbx** only supports that operation mode,
whereas **distrobox** allows for fine-grained control about what files/directories to share with the container.

If you only want to quickly run **MiniBrowser** / **cog**, etc. using **toolbx** is the most convenient way,
as it requires no configuration. However it is *impossible to isolate* a container launched with **toolbx**
from the **host system**. For exampe, compiling WebKit within the container, places **ccache** object files
in the ``~/.ccache`` directory, unless manually configured to be a different location. Installing **Python**
packages (per-user mode) within the container, usually places them in your ``~/.local`` directory. However
they might NOT be usuable from the **host** system - or vice-versa: you might install a package that requires
an already fulfilled dependency (due to a previous installation of that package, executed on the host system)
that in the end, doesn't work (depending on other C libraries with different ABI, version, etc.).
Furthermore all configuration for the developer tools, such as ``~/.gdbinit`` needs to reside in your regular
\$HOME directory -- again not immune to side effects, when mutating these files on the host system. Therefore
using **distrobox** is a wise choice to setup a stable, sustainable development environment!

### Setup procedure

On your **host system** ensure that **podman** is installed and either **toolbx**, **distrobox**, or both.

* [podman](https://podman.io)
  * Fedora: [podman](https://packages.fedoraproject.org/pkgs/podman/podman)
  * Debian (sid): [podman](https://packages.debian.org/sid/podman)
  * Ubuntu (starting from 22.04): [podman](https://packages.ubuntu.com/jammy/podman)
  * macOS: [podman](https://formulae.brew.sh/formula/podman)

* [toolbx](https://containertoolbx.org)
  * Fedora: [toolbox](https://packages.fedoraproject.org/pkgs/toolbox/toolbox/)
  * Debian (sid): [podman-toolbox](https://packages.debian.org/sid/podman-toolbox)
  * Ubuntu (starting from 22.04): [podman-toolbox](https://packages.ubuntu.com/jammy/podman-toolbox)

* [distrobox](https://distrobox.privatedns.org)
  * Fedora: [distrobox](https://packages.fedoraproject.org/pkgs/distrobox/distrobox/)
  * Debian (sid): [distrobox](https://packages.debian.org/sid/distrobox)
  * Ubuntu (before 22.10): [distrobox](https://snapcraft.io/install/distrobox/ubuntu) (snap-only)
  * Ubuntu (starting from 22.10): [distrobox](https://packages.ubuntu.com/kinetic/distrobox)
  * macOS: [distrobox](https://formulae.brew.sh/formula/distrobox)

That's all you need to install on your host system. Now it's the time to get a fresh WebKit source
checkout, or update/clean an existing one.

```sh
$ cd ~/path/to/home/subdirectory/with/git/checkout/of/
$ git clone https://github.com/WebKit/WebKit.git
```

That can take several hours, depending on your internet connection.
Now either proceed with the **Quick testing** instructions or skip to the **Full-fledget setup**
section.

### 1) Quick testing instructions using **toolbx**

This method requires no configuration of the container creation process
and shares your local \$HOME directory with the container, breaking the isolation
between host system and container for the sake of convenience.

1. Create the container

```sh
$ toolbox create -i docker.io/nikolaszimmermann/wkdev-sdk:latest wkdev-quick
```

2. Enter the container

```sh
$ toolbox enter wkdev-quick
```

3. You're ready to compile WebKit - move to next section.

### 2) Full-fledged setup

This method will create a dedicated \$HOME directory for the current user \$USER
within the container file system, bind-mounted to any directory you want on the
host side. The true \$HOME directory is available in **\$DISTROBOX_HOST_HOME** within
the container. The main benefit is that the container is not affected by any changes
in the host system XDG standard directories such as **~/.local/**, **~/.cache/**,
**~/.share/**, etc. Neither can the container pollute anything in the host system
\$HOME directory.

However the setup procedure is more complex: you need to think about where to store
e.g. GDB settings -- do you want e.g. **~/.gdbinit** shared with the host system?
Do you want a specific one only with WebKit related settings for the container
environment?

Using the the **toolbx** approach you have no choice but you have to alter configuration
files in your host \$HOME directory to change e.g. GDBs behavior within the container.
That is awkward and should be avoided for a day-by-day hacking environment, which
should be stable and hard to break, no matter what happens on the host side.

Finally, the steps to execute are:

1. Create a home directory for the wkdev container

Let's assume you want to create the container home directory inside your host \$HOME
directory, e.g.: **~/wkdev-home**:

```sh
cd /path/to/this/checkout
scripts/helpers/create-home-directory.sh ${HOME}/wkdev-home
```

The helper script checks permissions, ownership, copies shell configuration skeleton
files and handles shell specific quirks.

2. Create the container

```sh
$ distrobox create --name wkdev --image docker.io/nikolaszimmermann/wkdev-sdk:latest --home ${HOME}/wkdev-home
```

This pulls the latest revision of the **wkdev-sdk** from the [docker.io](https://docker.io)
container registry and creates a new local container named **wkdev** with a custom \$HOME
directory, isolated from the host home directory.

3. Enter the container

When entering the container the first time, distrobox will further customize the container
to be suitable for the developer: it tries to install the same shell as in the host system
and enables various other helper to work properly (sudo, etc.).

```sh
$ distrobox enter wkdev
```

You should see the installation procedure from distrobox. Be sure to inspect the log files,
as advised by distrobox: ``podman --remote logs -f wkdev`` is interessting to follow, to
see what is happening behind the scenes.

4. Customize your container

Most importantly, your shell needs to be configured. Other utilities, such as **gdb**,
that ship with the ``wkdev SDK`` need to be tuned as well. To aid the bootstrapping
procedure launch the **setup-wkdev-sdk.sh** scripts stored in the container image.

```sh
wkdev% /wkdev-sdk/container_scripts/setup-wkdev-sdk.sh
```

Follow the instructions and interactive setup wizard. After that the initial setup
procedure is finished.

5. You're ready to compile WebKit - move to next section.

## Compiling WebKit in the wkdev container

1. Enter the previously setup container (wkdev / wkdev-quick).

Use ``distrobox enter wkdev`` or ``toolbox enter wkdev-quick``.

2. Move to WebKit Git checkout

Now move to the place where you cloned the WebKit Git checkout:

```sh
cd ~/path/to/home/subdirectory/with/git/checkout/of/
```

3. Compile WebKit, run MiniBrowser and tests

Compile WebKit using the ``build-webkit`` command. Development builds currently
require a small quirk ('DENABLE_THUNDER=OFF') that will be resolved soon.
Running **MiniBrowser** or running the layout tests is just a matter of
launching the right WebKit helper script: ``run-minibrowser`` or ``run-webkit-tests``. In
case you are using a directory where you have compiled WebKit with flatpak in the past
you need to remove the ``WebKitBuild`` directory to start with a clean compilation.

Gtk debug build (CMake Debug buld):

```sh
Tools/Scripts/build-webkit --gtk --debug --cmakeargs "-DENABLE_THUNDER=OFF"
Tools/Scripts/run-minibrowser --gtk --debug
Tools/Scripts/run-webkit-tests --gtk --debug
```

Gtk release build (CMake RelWithDebInfo build):

```sh
Tools/Scripts/build-webkit --gtk --release
Tools/Scripts/run-minibrowser --gtk --release
Tools/Scripts/run-webkit-tests --gtk --release
```

That's it -- the ``wkdev SDK`` makes it trivial to compile & run & debug WebKit.

## Updating your container environment

If you want to update your development container to the latest revision, you
have to recreate it.

```
distrobox stop wkdev
distrobox rm wkdev
distrobox create --name wkdev --image docker.io/nikolaszimmermann/wkdev-sdk:latest --home ${HOME}/wkdev-home --pull
distrobox enter wkdev
```

That's it -- your \$HOME directory is re-used, no need to execute any other configuration.
