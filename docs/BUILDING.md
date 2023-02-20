## Building the container

There are two scripts available that encapsulate the build and deployment process of the ``wkdev SDK``:

```sh
host_scripts/wkdev-sdk-build
host_scripts/wkdev-sdk-deploy
```

See bootstrap.sh that builds the SDK and then tests it using wkdev-create.
NOTE: In future deployment should run via CI, to avoid having a single person with acess to the private key, or sharing keys.
