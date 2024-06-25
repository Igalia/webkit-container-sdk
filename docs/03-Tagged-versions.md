# Tagged versions

Over time the SDK will introduce major changes that will break behavior;
In order to easily use older versions we support tagged versions.

To use a specific tag the `wkdev-create` and `wkdev-sdk-bakery` commands take a `--tag`
argument. You can also set the `WKDEV_SDK_TAG` environment variable.

To get a list of available tags you can pass `--list-tags` to `wkdev-create`.

For example using an older image when creating a container:

```sh
wkdev-create --name='example-name' --tag='23.04'
```

As the scripts diverge from older images this *may* fail but for now should work fine.
However to use older scripts you can simply checkout the branch for that tag: `git checkout tag/23.04`.
This will use the `23.04` image by default but you may override as mentioned above.

## Creating a tag

The entire process of creating a tag is automated just create a branch named `tag/${tag_name}`
and CI will publish an image under that name.

