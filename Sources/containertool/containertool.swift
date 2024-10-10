//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import Foundation
import ContainerRegistry
import Basics

extension Swift.String: Swift.Error {}

enum AllowHTTP: String, ExpressibleByArgument, CaseIterable { case source, destination, both }

@main struct ContainerTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "containertool",
        abstract: "Build and upload a container image"
    )

    @Option(help: "Default registry for references which do not specify a registry") private var defaultRegistry:
        String = ProcessInfo.processInfo.environment["CONTAINERTOOL_DEFAULT_REGISTRY"] ?? "docker.io"

    @Option(help: "Repository path") private var repository: String

    @Argument(help: "Executable to package") private var executable: String

    @Option(help: "Username") private var username: String?

    @Option(help: "Password") private var password: String?

    @Flag(name: .shortAndLong, help: "Verbose output") private var verbose: Bool = false

    @Option(help: "Connect to the container registry using plaintext HTTP") var allowInsecureHttp: AllowHTTP?

    @Option(help: "CPU architecture") private var architecture: String =
        ProcessInfo.processInfo.environment["CONTAINERTOOL_ARCHITECTURE"] ?? "amd64"

    @Option(help: "Base image reference") private var from: String =
        ProcessInfo.processInfo.environment["CONTAINERTOOL_BASE_IMAGE"] ?? "swift:slim"

    @Option(help: "Operating system") private var os: String =
        ProcessInfo.processInfo.environment["CONTAINERTOOL_OS"] ?? "linux"

    @Option(help: "Tag for this manifest") private var tag: String?

    @Flag(inversion: .prefixedEnableDisable, exclusivity: .exclusive, help: "Load credentials from a netrc file")
    private var netrc: Bool = true

    @Option(help: "Specify the netrc file path") private var netrcFile: String?

    func run() async throws {
        let baseimage = try ImageReference(fromString: from, defaultRegistry: defaultRegistry)
        var destination_image = try ImageReference(fromString: repository, defaultRegistry: defaultRegistry)

        let authProvider: AuthorizationProvider?
        if !netrc {
            authProvider = nil
        } else if let netrcFile {
            guard FileManager.default.fileExists(atPath: netrcFile) else { throw "\(netrcFile) not found" }
            let customNetrc = URL(fileURLWithPath: netrcFile)
            authProvider = try NetrcAuthorizationProvider(customNetrc)
        } else {
            let defaultNetrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".netrc")
            authProvider = try NetrcAuthorizationProvider(defaultNetrc)
        }

        // Create clients for the source and destination registries
        // The base image may be stored on a different registry, so two clients are needed.
        // `scratch` is a special case and requires no source client.
        let source: RegistryClient?
        if from == "scratch" {
            source = nil
        } else {
            source = try await RegistryClient(
                registry: baseimage.registry,
                insecure: allowInsecureHttp == .source || allowInsecureHttp == .both,
                auth: .init(username: username, password: password, auth: authProvider)
            )
            if verbose { log("Connected to source registry: \(baseimage.registry)") }
        }

        let destination = try await RegistryClient(
            registry: destination_image.registry,
            insecure: allowInsecureHttp == .destination || allowInsecureHttp == .both,
            auth: .init(username: username, password: password, auth: authProvider)
        )

        if verbose { log("Connected to destination registry: \(destination_image.registry)") }
        if verbose { log("Using base image: \(baseimage)") }

        // MARK: Find the base image

        let baseimage_manifest: ImageManifest
        let baseimage_config: ImageConfiguration
        if let source {
            baseimage_manifest = try await source.getImageManifest(
                repository: baseimage.repository,
                reference: baseimage.reference,
                architecture: architecture
            )
            log("Found base image manifest: \(baseimage_manifest.digest)")

            baseimage_config = try await source.getImageConfiguration(
                repository: baseimage.repository,
                digest: baseimage_manifest.config.digest
            )
            log("Found base image configuration: \(baseimage_manifest.config.digest)")
        } else {
            baseimage_manifest = .init(
                schemaVersion: 2,
                config: .init(mediaType: "scratch", digest: "scratch", size: 0),
                layers: []
            )
            baseimage_config = .init(architecture: architecture, os: os, rootfs: .init(_type: "layers", diff_ids: []))
            if verbose { log("Using scratch as base image") }
        }

        // MARK: Build the application layer

        let executableURL = URL(fileURLWithPath: executable)
        let payload = try Data(contentsOf: executableURL)
        let payload_name = executableURL.lastPathComponent
        let tardiff = tar(payload, filename: payload_name)
        log("Built application layer")

        // MARK: Upload the application layer

        let application_layer = try await destination.uploadImageLayer(
            repository: destination_image.repository,
            layer: Data(tardiff)
        )

        if verbose { log("application layer: \(application_layer.digest) (\(application_layer.size) bytes)") }

        // MARK: Create the application configuration

        // The more convenient Date.now.ISO8601Format() is not present on Linux
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date.now)

        // Inherit the configuration of the base image - UID, GID, environment etc -
        // and override the entrypoint.
        var inherited_config = baseimage_config.config ?? .init()
        inherited_config.Entrypoint = ["/\(payload_name)"]
        inherited_config.Cmd = []
        inherited_config.WorkingDir = "/"

        let configuration = ImageConfiguration(
            created: now,
            architecture: architecture,
            os: os,
            config: inherited_config,
            rootfs: .init(
                _type: "layers",
                diff_ids: [
                    // The diff_id is the digest of the _uncompressed_ layer archive.
                    // It is used by the runtime, which might not store the layers in
                    // the compressed form in which it received them from the registry.
                    digest(of: tardiff)
                ] + baseimage_config.rootfs.diff_ids
            ),
            history: [.init(created: now, created_by: "containertool")]
        )

        let config_blob = try await destination.putImageConfiguration(
            repository: destination_image.repository,
            configuration: configuration
        )

        if verbose { log("image configuration: \(config_blob.digest) (\(config_blob.size) bytes)") }

        // MARK: Create application manifest

        let manifest = ImageManifest(
            schemaVersion: 2,
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            config: config_blob,
            layers: [application_layer] + baseimage_manifest.layers
        )

        // MARK: Upload base image

        // Copy the base image layers to the destination repository
        // Layers could be checked and uploaded concurrently
        // This could also happen in parallel with the application image build
        if let source {
            for layer in baseimage_manifest.layers {
                try await source.copyBlob(
                    digest: layer.digest,
                    fromRepository: baseimage.repository,
                    toClient: destination,
                    toRepository: destination_image.repository
                )
            }
        }

        // MARK: Upload application manifest

        // Use the manifest's digest if the user did not provide a human-readable tag
        // To support multiarch images, we should also create an an index pointing to
        // this manifest.
        let reference = tag ?? manifest.digest
        let location = try await destination.putManifest(
            repository: destination_image.repository,
            reference: destination_image.reference,
            manifest: manifest
        )

        if verbose { log(location) }

        destination_image.reference = reference
        print(destination_image)
    }
}
