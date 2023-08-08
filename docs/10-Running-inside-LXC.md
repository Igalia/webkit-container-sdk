# Running the SDK inside an LXC container

For running this inside an LXC container the following setup works:

1. Use a LXC privileged container.


2. Configure the LXC container config with the following lines

```
# tun/tap for podman
lxc.cgroup.devices.allow = c 10:200 rwm
lxc.cgroup2.devices.allow = c 10:200 rwm
lxc.mount.entry = /dev/net/tun dev/net/tun none bind,create=file

# Allow /dev/fuse
lxc.cgroup.devices.allow = c 10:229 rwm
lxc.mount.entry = /dev/fuse dev/fuse none bind,create=file 0 0
```
