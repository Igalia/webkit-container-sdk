## Building the SDK

`wkdev-sdk-bakery` encapsulates the whole process of building the SDK including all images. Just try it:

```sh
wkdev-sdk-bakery --mode build
```

### Adding patched projects to the SDK

If you want to build a patched version of a library to the SDK the easiest method is using JHBuild.

The [modulesets](https://gnome.pages.gitlab.gnome.org/jhbuild/moduleset-syntax.html) we use are
located in `images/wkdev_sdk/jhbuild/webkit-sdk-deps.modules` and you can add a new module there.

A simple example of a project with a patch would be:

```xml
  <meson id="example">
    <branch repo="example.org"
            module="foo-${version}.tar.gz"
            version="1.0.0"
            hash="sha256:92529aef9063f477d1975947c6388c63d03234018f45d007c07716dd3e21dd41"
            size="127651">
        <!-- strip=0 by default -->
        <patch file="https://example.org/something.patch" strip="1"/>
    </branch>
  </meson>
```

You can use a local file also but you will have to `COPY` it in `images/wkdev_sdk/Containerfile`.

This only works for tarballs, if you have a git source you can specify a different branch/commit with `tag`:

```xml
  <meson id="example">
    <branch repo="example.org"
            module="reponame.git"
            tag="28ba096781388c896e91618d3b9d14f7d5483273"/>
  </meson>
```

If you want it to be in the SDK you must then modify the `<metamodule id="webkit-sdk-deps">` element in
`webkit-sdk-deps.modules`, otherwise it will only be built when a user explicitly runs `jhbuild build ${module}`.
