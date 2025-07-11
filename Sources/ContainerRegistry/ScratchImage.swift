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

import struct Foundation.Data
import class Foundation.JSONEncoder

/// ScratchImage is a special-purpose ImageSource which represents the scratch image.
public struct ScratchImage {
    var encoder: JSONEncoder

    var architecture: String
    var os: String

    var configuration: ImageConfiguration
    var manifest: ImageManifest
    var manifestDescriptor: ContentDescriptor
    var index: ImageIndex

    public init(architecture: String, os: String) {
        self.encoder = containerJSONEncoder()

        self.architecture = architecture
        self.os = os

        self.configuration = ImageConfiguration(
            architecture: architecture,
            os: os,
            rootfs: .init(_type: "layers", diff_ids: [])
        )
        let encodedConfiguration = try! encoder.encode(self.configuration)

        self.manifest = ImageManifest(
            schemaVersion: 2,
            config: ContentDescriptor(
                mediaType: "application/vnd.oci.image.config.v1+json",
                digest: "\(ImageReference.Digest(of: encodedConfiguration))",
                size: Int64(encodedConfiguration.count)
            ),
            layers: []
        )
        let encodedManifest = try! encoder.encode(self.manifest)

        self.manifestDescriptor = ContentDescriptor(
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            digest: "\(ImageReference.Digest(of: encodedManifest))",
            size: Int64(encodedManifest.count)
        )

        self.index = ImageIndex(
            schemaVersion: 2,
            mediaType: "application/vnd.oci.image.index.v1+json",
            manifests: [
                ContentDescriptor(
                    mediaType: "application/vnd.oci.image.manifest.v1+json",
                    digest: "\(ImageReference.Digest(of: encodedManifest))",
                    size: Int64(encodedManifest.count),
                    platform: .init(architecture: architecture, os: os)
                )
            ]
        )
    }
}

extension ScratchImage: ImageSource {
    /// The scratch image has no data layers, so `getBlob` returns an empty data blob.
    ///
    /// - Parameters:
    ///   - repository: Name of the repository containing the blob.
    ///   - digest: Digest of the blob.
    /// - Returns: An empty blob.
    /// - Throws: Does not throw, but signature must match the `ImageSource` protocol requirements.
    public func getBlob(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Data {
        Data()
    }

    /// Returns an empty manifest for the scratch image, with no image layers.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the manifest to fetch.
    /// - Returns: The downloaded manifest.
    /// - Throws: Does not throw, but signature must match the `ImageSource` protocol requirements.
    public func getManifest(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> (ImageManifest, ContentDescriptor) {
        (self.manifest, self.manifestDescriptor)
    }

    /// Fetches an image index.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the index to fetch.
    /// - Returns: The downloaded index.
    /// - Throws: Does not throw, but signature must match the `ImageSource` protocol requirements.
    public func getIndex(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> ImageIndex {
        self.index
    }

    /// Returns an almost empty image configuration scratch image.
    /// The processor architecture and operating system fields are populated,
    /// but the layer list is empty.
    ///
    /// - Parameters:
    ///   - image: Reference to the image containing the record.
    ///   - digest: Digest of the record.
    /// - Returns: A suitable configuration for the scratch image.
    /// - Throws: Does not throw, but signature must match the `ImageSource` protocol requirements.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function retrieves the requested blob and tries to decode it as a configuration record.
    public func getImageConfiguration(
        forImage image: ImageReference,
        digest: ImageReference.Digest
    ) async throws -> ImageConfiguration {
        self.configuration
    }
}
