# Set up your registry credentials

Configure the plugin to authenticate to your container registry.

## Overview

Many container registries require authentication in order to push images, or even pull them.
The plugin reads your registry credentials from a `.netrc` file in your home directory.
Add a record into the `.netrc` file for each registry you use.
The plugin chooses the correct record based on the hostname of the registry's authentication server.

> For some registries, such as Docker Hub [(see example)](<doc:#Docker-Hub>), the authentication server hostname might not be the same as the registry hostname you use when pushing and pulling images.

The following example shows placeholder values for the registry `registry.example.com`:

```
machine registry.example.com
  login myuser
  password mypassword
```

The following examples show how to set up the plugin for some popular registry providers.

### Docker Hub

> Don't use your Docker Hub account password to push and pull images.
> Personal Access Tokens have restricted privileges and you can create a separate token for each integration you use, which you can monitor independently and revoke at any time.

1. Log into Docker Hub and [generate a Personal Access Token](https://docs.docker.com/security/for-developers/access-tokens/) for Swift Container Plugin.

2. **Set the token's access permissions to *Read & Write*.**

3. Copy the token and add it, together with your Docker ID, to your `.netrc` file under the machine name `auth.docker.io`:

```
machine auth.docker.io
  login mydockerid
  password dckr_pat_B3FwrU...
```
