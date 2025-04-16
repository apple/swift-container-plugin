# Set up your registry credentials

Configure Swift Container Plugin to authenticate to your container registry

## Overview

Many registries require authentication in order to push images, or even pull them.   The plugin can read your registry credentials from a `.netrc` file in your home directory.   You can add a netrc record for each registry you need to use, and the plugin will choose the correct one:

```
machine registry.example.com
  login myuser
  password mypassword
```