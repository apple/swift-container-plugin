# Swift Container Plugin

[![](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/apple/swift-container-plugin/documentation/containerimagebuilderplugin)
[![](https://img.shields.io/github/v/release/apple/swift-container-plugin?include_prereleases)](https://github.com/apple/swift-container-plugin/releases)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-container-plugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/apple/swift-container-plugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-container-plugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/apple/swift-container-plugin)
[![](https://github.com/apple/swift-container-plugin/actions/workflows/main.yml/badge.svg)](https://github.com/apple/swift-container-plugin/actions/workflows/main.yml/badge.svg)

Publish container images using Swift Package Manager.

Learn more about Swift Container Plugin in the [lightning talk](https://www.youtube.com/watch?v=9AaINsCfZzw) from [ServerSide.Swift 2024](https://www.serversideswift.info/speakers/euan-harris/).

## Overview

Swift Container Plugin provides a Swift Package Manager command plugin and utilities to make it easy to build container images for servers written in Swift.

> Container images are the standard way to package cloud software today.   Once you have packaged your server in a container image, you can deploy it on any container-based public or private cloud service, or run it locally using a desktop container runtime.

After setting up your project, you can use the plugin to build and publish a container image in one step:

```
% swift package --swift-sdk x86_64-swift-linux-musl \
        build-container-image --repository registry.example.com/myservice
...
Plugin ‘ContainerImageBuilder’ wants permission to allow all network connections on all ports.
Stated reason: “This command publishes images to container registries over the network”.
Allow this plugin to allow all network connections on all ports? (yes/no) yes
...
Building for debugging...
Build of product 'containertool' complete! (4.95s)
...
Build of product 'hello-world' complete! (5.51s)
...
[ContainerImageBuilder] Found base image manifest: sha256:7bd643386c6e65cbf52f6e2c480b7a76bce8102b562d33ad2aff7c81b7169a42
[ContainerImageBuilder] Found base image configuration: sha256:b904a448fde1f8088913d7ad5121c59645b422e6f94c13d922107f027fb7a5b4
[ContainerImageBuilder] Built application layer
[ContainerImageBuilder] Uploading application layer
[ContainerImageBuilder] Layer sha256:dafa2b0c44d2cfb0be6721f079092ddf15dc8bc537fb07fe7c3264c15cb2e8e6: already exists
[ContainerImageBuilder] Layer sha256:2565d8e736345fc7ba44f9b3900c5c20eda761eee01e01841ac7b494f9db5cf6: already exists
[ContainerImageBuilder] Layer sha256:2c179bb2e4fe6a3b8445fbeb0ce5351cf24817cb0b068c75a219b12434c54a58: already exists
registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df
```

You can then use a container runtime, such as `podman` to run the image:

```
% podman run -p 8080:8080 registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df
Trying to pull registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df...
...
2024-05-26T22:57:50+0000 info HummingBird : [HummingbirdCore] Server started and listening on 0.0.0.0:8080
```

## Getting Started

Swift Container Plugin requires Swift 6.0 and runs on macOS and Linux.   It does not require a local container runtime to be installed in order to build an image.

Learn more about setting up your project in the [ContainerImageBuilder plugin documentation](Sources/ContainerImageBuilderPluginDocumentation/Documentation.docc/ContainerImageBuilderPlugin.md).

Take a look at the [Examples](Examples).
