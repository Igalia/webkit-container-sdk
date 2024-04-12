# Tagged versions

Over time the SDK will introduce major changes that will break behavior;
In order to easily use older versions we support tagged versions.

There are two parts to a SDK version the scripts and the image.

## Images

To use an older image with the latest scripts you can set `WKDEV_SDK_TAG`, e.g.:

```sh
export WKDEV_SDK_TAG='23.04'
wkdev-create --name='example-name'
```

As the scripts diverge from older images this *may* fail but for now should work fine.

## Scripts

To use older scripts you can simply checkout the branch for that tag: `git checkout tag/23.04`.

This will use the `23.04` image by default but you may override it with `WKDEV_SDK_TAG`.

## Creating a tag

The entire process of creating a tag is automated just create a branch named `tag/${tag_name}`
and CI will publish an image under that name.

