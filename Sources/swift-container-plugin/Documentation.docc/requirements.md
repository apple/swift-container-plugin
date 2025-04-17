# Install a toolchain for cross-compilation

Install an open source Swift toolchain and a compatible Swift SDK to build Linux executables on macOS.

## Overview

* Swift Container Plugin runs on macOS and Linux and requires Swift 6.0 or later.
* On macOS you must install a cross-compilation Swift SDK, such as the [Swift Static Linux SDK](https://www.swift.org/documentation/articles/static-linux-getting-started.html), in order to build executables which can run on Linux-based cloud infrastructure.
* The Swift Static Linux SDK requires the [open source Swift toolchain](https://www.swift.org/install/macos/) to be installed.
* A container runtime is not required to build an image, but you will need one wherever you want to run the image.

### Install an open source Swift toolchain

Follow the instructions at [https://www.swift.org/install/macos/](https://www.swift.org/install/macos/) to install the open source Swift toolchain.   The easiest way to do this is to use the [Swiftly swift toolchain installer](https://www.swift.org/install/macos/swiftly/).

### Install a Swift SDK for cross-compilation which matches the open source toolchain

If you are running on macOS, you can use a [Swift SDK](https://github.com/apple/swift-evolution/blob/main/proposals/0387-cross-compilation-destinations.md) to cross-compile your server executable for Linux.   Either:

* Install the [Static Linux SDK from swift.org](https://www.swift.org/documentation/articles/static-linux-getting-started.html)
* Use [Swift SDK Generator](https://github.com/apple/swift-sdk-generator) to build and install a custom SDK

The following example illustrates installing the Swift Static Linux SDK:
```
% swift sdk install https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz --checksum 111c6f7d280a651208b8c74c0521dd99365d785c1976a6e23162f55f65379ac6
Downloading a Swift SDK bundle archive from `https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz`...
                                   Downloading
100% [=============================================================]
Downloading swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz

Swift SDK bundle archive successfully downloaded from `https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz`.
Verifying if checksum of the downloaded archive is valid...
Downloaded archive has a valid checksum.
Swift SDK bundle at `https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz` is assumed to be an archive, unpacking...
Swift SDK bundle at `https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz` successfully installed as swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.
```

After the installation is complete, check that the SDK is available:

```shell
% swift sdk list
swift-6.1-RELEASE_static-linux-0.0.1
```
