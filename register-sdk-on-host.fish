# To be sourced from your e.g. ~/.config/fish/config.fish to integrate wkdev-sdk with your host OS.
set --export WKDEV_SDK (dirname (readlink -m (status --current-filename)))
fish_add_path --global --path "$WKDEV_SDK/scripts"
fish_add_path --global --path "$WKDEV_SDK/scripts/host-only"
