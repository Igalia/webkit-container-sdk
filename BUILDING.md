## Building the container

There are only three steps to build _and_ deploy a new ``wkdev SDK``:

```sh
podman build --build-arg NUMBER_OF_PARALLEL_BUILDS=<XXX> -t docker.io/nikolaszimmermann/wkdev-sdk:latest .
podman login docker.io
podman push docker.io/nikolaszimmermann/wkdev-sdk:latest
```

See bootstrap.sh, that encapsulates the building / testing steps.
