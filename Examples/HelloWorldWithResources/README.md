# HelloWorldWithResources

This example shows you how to use a resource bundle in your service.   It builds a Hummingbird server which returns a randomly-selected image from its resource bundle.

1. [Install a Static Linux SDK](Sources/ContainerImageBuilderPluginDocumentation/Documentation.docc/ContainerImageBuilderPlugin.md#install-a-swift-sdk-for-cross-compilation-on-macos) for your Swift compiler.  For instance, this command installs the Static Linux SDK for Swift 6.1:
    ```
    % swift sdk install https://download.swift.org/swift-6.1-release/static-sdk/swift-6.1-RELEASE/swift-6.1-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
        --checksum 111c6f7d280a651208b8c74c0521dd99365d785c1976a6e23162f55f65379ac6
    ```

2. Build the service and upload it to a container registry:
    ```
    % swift package --swift-sdk aarch64-swift-linux-musl \
        --allow-network-connections all build-container-image \
        --repository registry.example.com/resources
    ```

3. Run the service:
    ```
    % podman run -it --rm -p 8080:8080 registry.example.com/resources
    ```

4. Access the service [from your browser](localhost:8080/).   It should return a random emoji chosen from the three images stored in the bundle.
