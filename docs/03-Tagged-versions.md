# Versioned releases

Each release of the SDK is published as a versioned image tag of the
form `<major>.<minor>-v<count>-<gitsha>`, for example
`2.53-v1-916f9ef`. The components mean:

* `<major>.<minor>` tracks the upstream WebKitGTK / WPE WebKit release
  cycle (starting at `2.53`). It is bumped by hand in the Containerfile
  when moving to a new branch, and is **not** the WebKit patch number:
  `2.53-v1` and WebKit `2.53.1` are independent.
* `v<count>` is the per-release-cycle SDK build counter, auto-bumped by
  the release workflow on every release. The first release for a given
  `<major>.<minor>` is `v1`, the next is `v2`, and so on.
* `<gitsha>` is the short SHA of the source-repo commit the image was
  built from, so any image can be traced back to its sources directly
  from the version string.

The `WKDEV_SDK_VERSION` ARG declared in `images/wkdev_sdk/Containerfile`
is the **single, exclusive source of truth** for the SDK version used
by every tool in this repo.

It is propagated to:

* the OCI image label `org.opencontainers.image.version`
* the file `/etc/wkdev-sdk-version` inside the running container
* the welcome message shown on container login
* the image tag used by `wkdev-create` and `wkdev-sdk-bakery`

The `WKDEV_SDK_VERSION` ARG is bumped automatically by the release
workflow, never by users. Stay on the latest `main` and your tooling
will pick up whatever version upstream most recently published.

## Discovering published versions

```sh
wkdev-create --list-tags
```

…queries the registry for available image tags. Use this to confirm a
particular version is published.

## Creating a container at a specific version

By default `wkdev-create` uses the version pinned in this checkout. To
spin up a container against any other published version, pass
`--version=<major>.<minor>-v<count>-<gitsha>`. The image is pulled
from the registry on demand:

```sh
wkdev-create --name wkdev-2.53-v1 --version=2.53-v1-abcdef0
```

You can also pass just `<major>.<minor>` and `wkdev-create` will
resolve it to the highest published `v<count>` for that branch (i.e.
the most recent SDK release on the WebKit `<major>.<minor>` cycle):

```sh
wkdev-create --name wkdev-2.53-latest --version=2.53
```

The `--version` flag only affects which **image** is used; the host-side
scripts (`wkdev-create`, `wkdev-enter`, `wkdev-update`, …) always come
from your current checkout. If you need an old SDK image and matching
old scripts (e.g. to reproduce a CI pipeline as it ran at a past
release), check out the corresponding git tag instead:
`git checkout wkdev-sdk-2.53-v1-abcdef0`.

Note that `wkdev-update` always targets the version pinned in the
Containerfile. If you deliberately created a container at a version
other than the one pinned, `wkdev-update` will flag it as `OUTDATED`
and prompt to recreate it on the pinned version. Answer `n` to keep
it, or recreate it manually with
`wkdev-create --rm --version=<major>.<minor>-v<count>-<gitsha>`.

## Upgrading an existing container

Run `wkdev-update`. It will:

1. `git pull --rebase` the local wkdev-sdk checkout (when on a clean
   `main`), adopting whatever version the upstream Containerfile pins.
2. Print the version pinned locally and the latest version available in
   the registry.
3. List your wkdev-sdk containers along with the version they were built
   from, flagging anything older than the target as `OUTDATED`.
   Containers built from images that carry no version label (e.g. older
   `:latest` images from before the versioning scheme) are also flagged
   as `OUTDATED` so they can be migrated to a versioned release.
4. Pull the target image and offer to recreate each outdated container.

## Creating a release

Releases are cut from `main` via the **Release wkdev-sdk** GitHub Actions
workflow (`.github/workflows/release-wkdev-sdk.yaml`):

1. Trigger the workflow manually (`workflow_dispatch`).
2. The workflow takes the `v<count>` component of `WKDEV_SDK_VERSION`
   in the Containerfile and appends a `-<gitsha>` suffix that records
   the source-repo commit the image was built from. If the previous
   value already carried a `-<gitsha>` (i.e. that count had already
   been released), the workflow first bumps `<count>`. It then commits
   the change and pushes a `wkdev-sdk-<major>.<minor>-v<count>-<gitsha>`
   git tag. `<major>.<minor>` bumps (which track upstream WebKitGTK /
   WPE release branches) are done by hand by editing the Containerfile
   and resetting the counter to `v1` so the first release on the new
   branch is `v1`.
3. Pushing the tag triggers `build-and-publish-wkdev-sdk-image.yaml`,
   which builds the multi-arch image and publishes
   `ghcr.io/igalia/wkdev-sdk:<major>.<minor>-v<count>-<gitsha>`.

Downstream consumers (e.g. `webkit-container-sdk-bots`) are not auto-notified;
they pin to a specific SDK version of their own choosing and bump it on their
own schedule.

## Migrating from the pre-versioning workflow

Earlier revisions of this repository did not have a versioning scheme:
images were always published under the rolling `:latest` tag, an
optional `WKDEV_SDK_TAG` environment variable / `--tag` CLI flag let
callers select a side-tagged image, and experimental builds were
produced from `tag/<name>` git branches. **All of those mechanisms have
been removed.** Drop any `WKDEV_SDK_TAG` overrides and `--tag`
arguments to `wkdev-create` / `wkdev-sdk-bakery` / `wkdev-update`, and
stop pushing `tag/*` branches. To select an arbitrary published image,
use `wkdev-create --version=<major>.<minor>-v<count>-<gitsha>` (see
above). Existing containers built from `:latest` are auto-detected and
offered for migration on the next `wkdev-update` run.
