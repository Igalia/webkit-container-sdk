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
cd /path/to/WebKit
export WEBKIT_USE_SCCACHE=0
# cross-build WebKit
Tools/Scripts/build-webkit --cross-target=rpi4-64bits-mesa --wpe --release
# build the image
Tools/Scripts/cross-toolchain-helper --cross-target=rpi4-64bits-mesa --build-image
```

sccache is not supported in this mode, and will interfere with yocto -- disable it.

Follow the instructions in Tools/yocto/README.md to flash the image onto your target machine.
