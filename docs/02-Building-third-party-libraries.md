## Building third-party libraries

As the container is a normal Ubuntu installation there are many ways to install custom libraries
however we have a solution to make this easier. [JHBuild](https://gnome.pages.gitlab.gnome.org/jhbuild/index.html)
is a tool that automates downloading, building, and installing projects and is provided in the SDK.

#### Hacking on glib with JHBuild

1. Build glib master

```sh
jhbuild build glib
```

This will do an initial build of glib and its dependencies.

2. Modify and reinstall glib

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