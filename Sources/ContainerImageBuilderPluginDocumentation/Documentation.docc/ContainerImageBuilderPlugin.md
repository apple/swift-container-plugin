# ``ContainerImageBuilderPlugin``

Publish container images from Swift Package Manager.

@Metadata {
    @DisplayName("ContainerImageBuilder Plugin")
}

## Overview

> Container images are the standard way to package cloud software today. Once you have packaged your server in a container image, you can deploy it on any container-based public or private cloud service, or run it locally using a desktop container runtime.

The ContainerImageBuilder plugin is a Swift Package Manager command plugin which can publish a container image for any executable target defined in `Package.swift`.

* `containertool` is a tool which packs any executable into a container image.
* `ContainerImageBuilder` is a Swift Package Manager command plugin which uses `containertool` to build a container image for any executable target in a single command.

The plugin requires Swift 6.0 and runs on macOS and Linux.
The plugin does not require a container runtime to be installed locally in order to build an image.

Try one of the [Examples](../../../Examples)

## Install a Swift SDK for cross-compilation on macOS

If you are running on macOS, you can use a [Swift SDK](https://github.com/apple/swift-evolution/blob/main/proposals/0387-cross-compilation-destinations.md) to cross-compile your server executable for Linux.   Either:

* Install the [Static Linux SDK from swift.org](https://www.swift.org/documentation/articles/static-linux-getting-started.html)
* Use [Swift SDK Generator](https://github.com/apple/swift-sdk-generator) to build and install a custom SDK

Check that the SDK is available.   In this case we have installed the Swift Static Linux SDK:

```shell
% swift sdk list
swift-6.0.1-RELEASE_static-linux-0.0.1
```

> Note: To use the Static Linux SDK on macOS, you must [install the open source Swift toolchain from swift.org](https://www.swift.org/documentation/articles/static-linux-getting-started.html#installing-the-sdk)

## Add the plugin to your project

Swift Container Plugin is distributed as a Swift Package Manager package.   Use the `swift package` command to add it to your project:

```shell
swift package add-dependency https://github.com/apple/swift-container-plugin --from 0.1.0
```

Alternatively, append the following lines to `Package.swift`:

```swift
package.dependencies += [
    .package(url: "https://github.com/apple/swift-container-plugin", from: "0.1.0"),
]
```

Check that `ContainerImageBuilder` is now available in Swift Package Manager:

```shell
% swift package plugin --list
‘build-container-image’ (plugin ‘ContainerImageBuilder’ in package ‘swift-container-plugin)
```

## Add your registry credentials to .netrc

Many registries require authentication in order to push images, or even pull them.   The plugin can read your registry credentials from a `.netrc` file in your home directory.   You can add a netrc record for each registry you need to use:

```
machine registry.example.com
  login myuser
  password mypassword
```

## Build and package your service

`build-container-image` takes care of building your service, packaging it in a container image and uploading it to a container registry, all in one command:

```shell
% swift package --swift-sdk x86_64-swift-linux-musl \
        build-container-image --from swift:slim --repository registry.example.com/myservice
```

* The `--swift-sdk` argument specifies the Swift SDK with which to build the executable.   In this case we are using the Static Linux SDK which was installed earlier.
* The `--from` argument specifies the base image on which our service will run.   `swift:slim` is the default.
* The `--repository` argument specifies where ContainerImageBuilder will upload our finished image.

The plugin needs permission to connect to the network to publish the image to the registry:

```
Plugin ‘ContainerImageBuilder’ wants permission to allow all network connections on all ports.
Stated reason: “This command publishes images to container registries over the network”.
Allow this plugin to allow all network connections on all ports? (yes/no)
```

Type `yes` to continue.

```
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

When it finishes, ContainerImageBuilder prints a reference identifying the new image.   Any standard container runtime can use the reference to pull and run your service.

## Run your service

For example, you could use `podman` to run the service locally, making it available on port 8080:

```
% podman run -p 8080:8080 registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df
Trying to pull registry.example.com/myservice@sha256:a3f75d0932d052dd9d448a1c9040b16f9f2c2ed9190317147dee95a218faf1df...
...
2024-05-26T22:57:50+0000 info HummingBird : [HummingbirdCore] Server started and listening on 0.0.0.0:8080
```
