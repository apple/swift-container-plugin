//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Date
import struct Foundation.URL

import ContainerRegistry
import Tar

func publishContainerImage<Destination: ImageDestination>(
    baseImage: ImageReference,
    destinationImage: ImageReference,
    source: RegistryClient?,
    destination: Destination,
    architecture: String,
    os: String,
    resources: [String],
    tag: String?,
    verbose: Bool,
    executableURL: URL
) async throws -> ImageReference {

    // MARK: Find the base image

    let baseImageManifest: ImageManifest
    let baseImageConfiguration: ImageConfiguration
    let baseImageDescriptor: ContentDescriptor
    if let source {
        (baseImageManifest, baseImageDescriptor) = try await source.getImageManifest(
            forImage: baseImage,
            architecture: architecture
        )
        try log("Found base image manifest: \(ImageReference.Digest(baseImageDescriptor.digest))")

        baseImageConfiguration = try await source.getImageConfiguration(
            forImage: baseImage,
            digest: ImageReference.Digest(baseImageManifest.config.digest)
        )
        log("Found base image configuration: \(baseImageManifest.config.digest)")
    } else {
        baseImageManifest = .init(
            schemaVersion: 2,
            config: .init(mediaType: "scratch", digest: "scratch", size: 0),
            layers: []
        )
        baseImageConfiguration = .init(
            architecture: architecture,
            os: os,
            rootfs: .init(_type: "layers", diff_ids: [])
        )
        if verbose { log("Using scratch as base image") }
    }

    // MARK: Upload resource layers

    var resourceLayers: [(descriptor: ContentDescriptor, diffID: ImageReference.Digest)] = []
    for resourceDir in resources {
        let resourceTardiff = try Archive().appendingRecursively(atPath: resourceDir).bytes
        let resourceLayer = try await destination.uploadLayer(
            repository: destinationImage.repository,
            contents: resourceTardiff
        )

        if verbose {
            log("resource layer: \(resourceLayer.descriptor.digest) (\(resourceLayer.descriptor.size) bytes)")
        }

        resourceLayers.append(resourceLayer)
    }

    // MARK: Upload the application layer

    let applicationLayer = try await destination.uploadLayer(
        repository: destinationImage.repository,
        contents: try Archive().appendingFile(at: executableURL).bytes
    )
    if verbose {
        log("application layer: \(applicationLayer.descriptor.digest) (\(applicationLayer.descriptor.size) bytes)")
    }

    // MARK: Create the application configuration

    let timestamp = Date(timeIntervalSince1970: 0).ISO8601Format()

    // Inherit the configuration of the base image - UID, GID, environment etc -
    // and override the entrypoint.
    var inheritedConfiguration = baseImageConfiguration.config ?? .init()
    inheritedConfiguration.Entrypoint = ["/\(executableURL.lastPathComponent)"]
    inheritedConfiguration.Cmd = []
    inheritedConfiguration.WorkingDir = "/"

    let configuration = ImageConfiguration(
        created: timestamp,
        architecture: architecture,
        os: os,
        config: inheritedConfiguration,
        rootfs: .init(
            _type: "layers",
            // The diff_id is the digest of the _uncompressed_ layer archive.
            // It is used by the runtime, which might not store the layers in
            // the compressed form in which it received them from the registry.
            diff_ids: baseImageConfiguration.rootfs.diff_ids
                + resourceLayers.map { "\($0.diffID)" }
                + ["\(applicationLayer.diffID)"]
        ),
        history: [.init(created: timestamp, created_by: "containertool")]
    )

    let configurationBlobReference = try await destination.putImageConfiguration(
        forImage: destinationImage,
        configuration: configuration
    )

    if verbose {
        log("image configuration: \(configurationBlobReference.digest) (\(configurationBlobReference.size) bytes)")
    }

    // MARK: Create application manifest

    let manifest = ImageManifest(
        schemaVersion: 2,
        mediaType: "application/vnd.oci.image.manifest.v1+json",
        config: configurationBlobReference,
        layers: baseImageManifest.layers
            + resourceLayers.map { $0.descriptor }
            + [applicationLayer.descriptor]
    )

    // MARK: Upload base image

    // Copy the base image layers to the destination repository
    // Layers could be checked and uploaded concurrently
    // This could also happen in parallel with the application image build
    if let source {
        for layer in baseImageManifest.layers {
            try await source.copyBlob(
                digest: ImageReference.Digest(layer.digest),
                fromRepository: baseImage.repository,
                toClient: destination,
                toRepository: destinationImage.repository
            )
        }
    }

    // MARK: Upload application manifest

    let manifestDescriptor = try await destination.putManifest(
        repository: destinationImage.repository,
        reference: destinationImage.reference,
        manifest: manifest
    )

    if verbose {
        log("manifest: \(manifestDescriptor.digest) (\(manifestDescriptor.size) bytes)")
    }

    // Use the manifest's digest if the user did not provide a human-readable tag
    // To support multiarch images, we should also create an an index pointing to
    // this manifest.
    let reference: ImageReference.Reference
    if let tag {
        reference = try ImageReference.Tag(tag)
    } else {
        reference = try ImageReference.Digest(manifestDescriptor.digest)
    }

    var result = destinationImage
    result.reference = reference
    return result
}
