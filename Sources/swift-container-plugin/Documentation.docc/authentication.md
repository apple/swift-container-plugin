# Set up your registry credentials

Configure the plugin to authenticate to your container registry.

## Overview

Many container registries require authentication in order to push images, or even pull them.
The plugin reads your registry credentials from a `.netrc` file in your home directory.
Add a record into the `.netrc` file for each registry you use, the plugin uses the authentication by the registry you choose.

The following example shows placeholder values for the registry `registry.example.com`:

```
machine registry.example.com
  login myuser
  password mypassword
```