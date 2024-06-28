## Cross-compiling inside the SDK

To cross-compile WebKit for different machines, WebKit provides a yocto based environment.
See /path/to/WebKit/Tools/yocto/README.md for details. You do not need to cross-compile from
within the SDK, but if you want to do it, here are some instructions:

First be sure to setup the environment, so that yocto caches downloads/sstate information:
```
export DL_DIR="${HOME}/.cache/yocto/downloads"
export SSTATE_DIR="${HOME}/.cache/yocto/sstate"
export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} DL_DIR SSTATE_DIR"
```

Then proceed with the compilation:

```
unset LD_LIBRARY_PATH
export NUMBER_OF_PROCESSORS=12 # Adapt to your machine.
export WEBKIT_USE_SCCACHE=0
Tools/Scripts/cross-toolchain-helper --cross-target rpi3-32bits-mesa --build-image
Tools/Scripts/cross-toolchain-helper --cross-target rpi3-32bits-mesa --build-toolchain
Tools/Scripts/cross-toolchain-helper --cross-target rpi3-32bits-mesa --cross-toolchain-run-cmd CFLAGS="" CPPFLAGS="" WebKitBuild/CrossToolChains/rpi3-32bits-mesa/build/toolchain/sysroots/x86_64-pokysdk-linux/post-relocate-setup.d/meson-setup.py
Tools/Scripts/cross-toolchain-helper --cross-target rpi3-32bits-mesa --cross-toolchain-run-cmd Tools/Scripts/build-webkit --wpe --release
```

It is important to unset the `LD_LIBRARY_PATH` otherwise `cross-toolchain-helper` will partly fail,
but `build-webkit` continues, leading to an inconsistent build environment, that will fail to produce binaries.

sccache is also not supported in that mode, and will interefer with yocto - disable it.

Follow the instructions in Tools/yocto/README.md to flash the image onto your target machine.
