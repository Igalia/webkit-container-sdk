# To be sourced from your e.g. ~/.config/fish/config.fish to integrate wkdev-sdk with your host OS.
set --export WKDEV_SDK (dirname (readlink -m (status --current-filename)))
set --global --export --append --path "$WKDEV_SDK/scripts"
set --global --export --append --path "$WKDEV_SDK/scripts/host-only"
