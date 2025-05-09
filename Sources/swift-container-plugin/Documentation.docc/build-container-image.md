# build-container-image plugin

Wrap a binary in a container image and publish it.

## Overview

`build-container-image` is a Swift Package Manager [command plugin](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md#using-a-package-plugin) which packages a product defined in `Package.swift` in a container image and publishes it to repository on a container registry.

### Usage

`swift package build-container-image [<options>]`

### Options

- term `--product <product>`:
  The name of the product to package.

  If `Package.swift` defines only one product, it will be selected by default.

### Source and destination repository options

- term  `--default-registry <default-registry>`:
  The default registry hostname. (default: `docker.io`)

  If the repository path does not contain a registry hostname, the default registry will be prepended to it.

- term  `--repository <repository>`:
  Destination image repository.

  If the repository path does not begin with a registry hostname, the default registry will be prepended to the path.
  The destination repository must be specified, either by setting the `--repository` option or the `CONTAINERTOOL_REPOSITORY` environment variable.

- term  `--tag <tag>`:
  The tag to apply to the destination image.

  The `latest` tag is automatically updated to refer to the published image.

- term  `--from <from>`:
  Base image reference. (default: `swift:slim`)

### Image build options

- term  `--resources <resources>`:
  Add the file or directory at `resources` to the image.
  Directories are added recursively.

  If the `product` being packaged has a [resource bundle](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package) it will be added to the image automatically.

### Image configuration options

- term  `--architecture <architecture>`:
  CPU architecture required to run the image.

  If the base image is `scratch`, the final image will have no base layer and will consist only of the application layer and resource bundle layer, if the product has a resource bundle.

- term  `--os <os>`:
  Operating system required to run the image. (default: `linux`)

### Authentication options

- term  `--default-username <username>`:
  Default username to use when logging into the registry.

  This username is used if there is no matching `.netrc` entry for the registry, there is no `.netrc` file, or the `--disable-netrc` option is set.
  The same username is used for the source and destination registries.

- term  `--default-password <password>`:
  Default password to use when logging into the registry.

  This password is used if there is no matching `.netrc` entry for the registry, there is no `.netrc` file, or the `--disable-netrc` option is set.
  The same password is used for the source and destination registries.

- term  `--enable-netrc/--disable-netrc`:
  Load credentials from a netrc file (default: `--enable-netrc`)

- term  `--netrc-file <netrc-file>`:
  The path to the `.netrc` file.

- term  `--allow-insecure-http <allow-insecure-http>`:
  Connect to the container registry using plaintext HTTP. (values: `source`, `destination`, `both`)

### Options

- term  `-v, --verbose`:
  Verbose output.

- term  `-h, --help`:
  Show help information.

### Environment

- term `CONTAINERTOOL_DEFAULT_REGISTRY`:
  Default image registry hostname, used when the repository path does not contain a registry hostname.
  (default: `docker.io`)

- term `CONTAINERTOOL_REPOSITORY`:
  The destination image repository.

  If the path does not begin with a registry hostname, the default registry will be prepended to the path.
  The destination repository must be specified, either by setting the `--repository` option or the `CONTAINERTOOL_REPOSITORY` environment variable.

- term `CONTAINERTOOL_BASE_IMAGE`:
  Base image on which to layer the application.
  (default: `swift:slim`)

- term `CONTAINERTOOL_OS`:
  Operating system.
  (default: `Linux`)
