# Add the plugin to your project

Make Swift Container Plugin available in your project.

## Overview

Swift Container Plugin is distributed as a Swift Package Manager package.    To make it available, you must add it as a dependency of your project.

### Install the plugin using the `swift package` CLI

Recent versions of `swift package` suupport the `add-dependency` command:

```shell
swift package add-dependency https://github.com/apple/swift-container-plugin --from 0.5.0
```

### Install the plugin by manually editing `Package.swift`

If you cannot use the `swift package add-dependency` comand, append the following lines to your project's `Package.swift` file:

```swift
package.dependencies += [
    .package(url: "https://github.com/apple/swift-container-plugin", from: "0.5.0"),
]
```

### Check that the plugin is available

After installation, Swift Package Manager should show that the `ContainerImageBuilder` is now available:

```shell
% swift package plugin --list
‘build-container-image’ (plugin ‘ContainerImageBuilder’ in package ‘swift-container-plugin)
```