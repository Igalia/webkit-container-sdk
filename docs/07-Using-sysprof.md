# Using sysprof with webkit-container-sdk

This guide explains how to profile applications using `sysprof-cli` from within the webkit-container-sdk container and how to configure passwordless profiling on the host system.

## Overview

`sysprof-cli` is a system profiling tool that captures performance data from running applications. When used from within a container, it communicates with the host's `sysprofd` daemon via D-Bus, which requires authentication through polkit by default.

## Basic Usage

To profile an application with sysprof-cli:

```bash
sysprof-cli -f capture.syscap -- your-application [arguments]
```

For example, to profile MiniBrowser:
```bash
sysprof-cli -f profile.syscap -- run-minibrowser --wpe -- --fullscreen https://example.com
```

## Configuring Passwordless Profiling

By default, sysprof requires authentication each time you start profiling. To avoid this, you can create a polkit rule on the host system.

### Step 1: Create a polkit rule

Create a file with the following content:

```bash
sudo tee /etc/polkit-1/rules.d/99-sysprof-noauth.rules > /dev/null << EOF
// Allow specific user to use sysprof without authentication
polkit.addRule(function(action, subject) {
    if (action.id == "org.gnome.sysprof3.profile" &&
        subject.user == "$USERNAME") {
        return polkit.Result.YES;
    }
});
EOF

# Set correct permissions
sudo chmod 644 /etc/polkit-1/rules.d/99-sysprof-noauth.rules

# Restart polkit to apply changes
sudo systemctl restart polkit
```

### Step 2: Verify the configuration

After installing the rule, you should be able to run `sysprof-cli` from within the container without being prompted for authentication.

## Viewing Profile Results

After capturing a profile, you can view it using the sysprof GUI application:

```bash
# From the host system
sysprof capture.syscap
```
