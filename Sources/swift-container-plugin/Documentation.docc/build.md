# Build and package your service

Build a container image and upload it to a registry.

## Overview

The plugin exposes the command `build-container-image` which you invoke to build your service, package it in a container image and upload it to a container registry, in a single command:

```shell
% swift package --swift-sdk x86_64-swift-linux-musl \
        build-container-image --from swift:slim --repository registry.example.com/myservice
```

* The `--swift-sdk` argument specifies the Swift SDK with which to build the executable.   In this case we are using the Static Linux SDK, [installed earlier](<doc:requirements>), to build an statically-linked x86_64 Linux binary.
* The `--from` argument specifies the base image on which our service will run.   `swift:slim` is the default, but you can choose your own base image or use `scratch` if your service does not require a base image at all.
* The `--repository` argument specifies the repository to which the plugin will upload the finished image.

> Note: on macOS, the plugin needs permission to connect to the network to publish the image to the registry.
>
> ```
> Plugin ‘ContainerImageBuilder’ wants permission to allow all network connections on all ports.
> Stated reason: “This command publishes images to container registries over the network”.
> Allow this plugin to allow all network connections on all ports? (yes/no)
> ```
>
> Type `yes` to continue.

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

When the plugin finishes, it prints a reference identifying the new image.
Any standard container runtime can use the reference to pull and run your service.
