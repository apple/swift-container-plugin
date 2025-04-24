# ``containertool``

Wrap a binary in a container image and publish it.

## Overview

`containertool` is a helper tool which can publish a container image for any executable passed in on the command line.

> Note: A container image is the standard way to package cloud software.   Once you have wrapped your server in a container image, you can deploy it on any public or private cloud service based on [Kubernetes](https://kubernetes.io), or run it locally using a desktop container runtime.

### Usage

`containertool` can be run directly but its main role is to be a helper tool used by the `ContainerImageBuilder` command plugin.   See the plugin documentation for examples of how to use it in this way.

```text
OVERVIEW: Build and publish a container image

USAGE: containertool --repository <repository> <executable> [--username <username>] [--password <password>] [--verbose] [--allow-insecure-http <allow-insecure-http>] [--architecture <architecture>] --from <from> [--os <os>] [--tag <tag>]

ARGUMENTS:
  <executable>            Executable to package

OPTIONS:
  --repository <repository>
                          Repository path
  --resources <resources> Resource bundle directory
  --username <username>   Username
  --password <password>   Password
  -v, --verbose           Verbose output
  --allow-insecure-http <allow-insecure-http>
                          Connect to the container registry using plaintext HTTP (values: source, destination, both)
  --architecture <architecture>
                          CPU architecture (default: amd64)
  --from <from>           Base image reference
  --os <os>               Operating system (default: linux)
  --tag <tag>             Tag for this manifest
  --enable-netrc/--disable-netrc
                          Load credentials from a netrc file (default:
                          --enable-netrc)
  --netrc-file <netrc-file>
                          Specify the netrc file path
  -h, --help              Show help information.
```
