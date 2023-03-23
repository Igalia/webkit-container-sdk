## TODO List

- Document debuginfod support
  --> We dynamically download debug packages via debuginfo (new in Ubuntu 22.10).
      They are working also to provide source code via this service in the next few
      months (already in Fedora since v35). Soon, without doing anything, we can
      enjoy full source code debugging of the whole stack.

- Document VSCode + podman-container usage
  --> Should work out-of-the-box, if clangd is there....

- Fix issues with LLVM toolchain (currently cannot be installed as-is)
