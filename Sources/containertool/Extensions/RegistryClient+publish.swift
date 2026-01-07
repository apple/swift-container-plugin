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

import class Foundation.FileManager
import struct Foundation.ObjCBool
import struct Foundation.Date
import struct Foundation.URL

import ContainerRegistry
import Tar

func publishContainerImage<Source: ImageSource, Destination: ImageDestination>(
    baseImage: ImageReference,
    destinationImage: ImageReference,
    source: Source,
    destination: Destination,
    architecture: String,
    os: String,
    entrypoint: String?,
    cmd: [String],
    resources: [String],
    tag: String?,
    verbose: Bool,
    executableURL: URL
) async throws -> ImageReference {

    // MARK: Find the base image

    let (baseImageManifest, baseImageDescriptor) = try await source.getImageManifest(
        forImage: baseImage,
        architecture: architecture
    )
    try log("Found base image manifest: \(ImageReference.Digest(baseImageDescriptor.digest))")

    let baseImageConfiguration = try await source.getImageConfiguration(
        forImage: baseImage,
        digest: ImageReference.Digest(baseImageManifest.config.digest)
    )
    log("Found base image configuration: \(baseImageManifest.config.digest)")

    // MARK: Upload resource layers

    var resourceLayers: [(descriptor: ContentDescriptor, diffID: ImageReference.Digest)] = []
    for resourceDir in resources {
        let paths = resourceDir.split(separator: ":", maxSplits: 1)
        switch paths.count {
        case 1:
            let resourceTardiff = try Archive().appendingRecursively(atPath: resourceDir).bytes
            let resourceLayer = try await destination.uploadLayer(
                repository: destinationImage.repository,
                contents: resourceTardiff
            )

            if verbose {
                log("resource layer: \(resourceLayer.descriptor.digest) (\(resourceLayer.descriptor.size) bytes)")
            }

            resourceLayers.append(resourceLayer)
        case 2:
            let sourcePath = paths[0]
            let destinationPath = paths[1]

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: String(sourcePath), isDirectory: &isDirectory) else {
                preconditionFailure("Source does not exist: \(source)")
            }

            let archive: Archive
            if isDirectory.boolValue {
                // archive = try Archive().appendingDirectoryTree(at: URL(fileURLWithPath: String(sourcePath)))
                preconditionFailure("Directory trees are not supported yet")
            } else {
                archive = try Archive()
                    .appendingFile(
                        at: URL(fileURLWithPath: String(sourcePath)),
                        to: URL(fileURLWithPath: String(destinationPath))
                    )
            }

            let resourceLayer = try await destination.uploadLayer(
                repository: destinationImage.repository,
                contents: archive.bytes
            )

            if verbose {
                log("resource layer: \(resourceLayer.descriptor.digest) (\(resourceLayer.descriptor.size) bytes)")
            }

            resourceLayers.append(resourceLayer)
        default:
            preconditionFailure("Invalid resource directory: \(resourceDir)")
        }
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
    if let entrypoint {
        inheritedConfiguration.Entrypoint = [entrypoint]
    } else {
        inheritedConfiguration.Entrypoint = ["/\(executableURL.lastPathComponent)"]
    }
    inheritedConfiguration.Cmd = cmd
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
    for layer in baseImageManifest.layers {
        try await source.copyBlob(
            digest: ImageReference.Digest(layer.digest),
            fromRepository: baseImage.repository,
            toClient: destination,
            toRepository: destinationImage.repository
        )
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

    // MARK: Create application index

    let index = ImageIndex(
        schemaVersion: 2,
        mediaType: "application/vnd.oci.image.index.v1+json",
        manifests: [
            ContentDescriptor(
                mediaType: manifestDescriptor.mediaType,
                digest: manifestDescriptor.digest,
                size: Int64(manifestDescriptor.size),
                platform: .init(architecture: architecture, os: os)
            )
        ]
    )

    // MARK: Upload application manifest

    let indexDescriptor = try await destination.putIndex(
        repository: destinationImage.repository,
        reference: destinationImage.reference,
        index: index
    )

    if verbose {
        log("index: \(indexDescriptor.digest) (\(indexDescriptor.size) bytes)")
    }

    // Use the index digest if the user did not provide a human-readable tag
    // To support multiarch images, we should also create an an index pointing to
    // this manifest.
    let reference: ImageReference.Reference
    if let tag {
        reference = try ImageReference.Tag(tag)
    } else {
        reference = try ImageReference.Digest(indexDescriptor.digest)
    }

    var result = destinationImage
    result.reference = reference
    return result
}
