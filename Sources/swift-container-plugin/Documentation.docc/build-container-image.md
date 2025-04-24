# build-container-image plugin

Wrap a binary in a container image and publish it.

## Overview

`build-container-image` is a Swift Package Manager [command plugin](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md#using-a-package-plugin) which packages a product defined in `Package.swift` in a container image and publishes it to repository on a container registry.

### Usage

`swift package build-container-image [<options>] --repository <repository>`

### Options

- term `--product <product>`:
  The name of the product to package.

  If `Package.swift` defines only one product, it will be selected by default.

- term  `--default-registry <default-registry>`:
  The default registry hostname. (default: `docker.io`)

  If the value of the `--repository` argument does not contain a registry hostname, the default registry will be prepended to the repository path.

- term  `--repository <repository>`:
  The repository path.

  If the path does not begin with a registry hostname, the default registry will be prepended to the path.

- term  `--resources <resources>`:
  Add the file or directory at `resources` to the image.
  Directories are added recursively.

  If the `product` being packaged has a [resource bundle](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package) it will be added to the image automatically.

- term  `--username <username>`:
  Username to use when logging into the registry.

  The same username is used for the source and destination registries.
  The `.netrc` file is ignored when this option is specified.

- term  `--password <password>`:
  Password to use when logging into the registry.

  The same password is used for the source and destination registries.
  The `.netrc` file is ignored when this option is specified.

- term  `-v, --verbose`:
  Verbose output.

- term  `--allow-insecure-http <allow-insecure-http>`:
  Connect to the container registry using plaintext HTTP. (values: `source`, `destination`, `both`)

- term  `--architecture <architecture>`:
  CPU architecture to record in the image.

- term  `--from <from>`:
  Base image reference. (default: `swift:slim`)

  If the base image is `scratch`, the final image will have no base layer and will consist only of the application layer and resource bundle layer, if the product has a resource bundle.

- term  `--os <os>`:
  Operating system to record in the image. (default: `linux`)

- term  `--tag <tag>`:
  Tag for this manifest.

  The `latest` tag is automatically updated to refer to the published image.

- term  `--enable-netrc/--disable-netrc`:
  Load credentials from a netrc file (default: `--enable-netrc`)

- term  `--netrc-file <netrc-file>`:
  The path to the `.netrc` file.

- term  `-h, --help`:
  Show help information.

### Environment

- term `CONTAINERTOOL_DEFAULT_REGISTRY`:
  Default image registry hostname, used when the `--repository` argument does not contain a registry hostname.
  (default: `docker.io`)

- term `CONTAINERTOOL_BASE_IMAGE`:
  Base image on which to layer the application.
  (default: `swift:slim`)

- term `CONTAINERTOOL_OS`:
  Operating system to encode in the container image.
  (default: `Linux`)
