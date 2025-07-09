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

/// A destination, such as a registry, to which container images can be uploaded.
public protocol ImageDestination {
    /// Checks whether a blob exists.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - digest: Digest of the requested blob.
    /// - Returns: True if the blob exists, otherwise false.
    /// - Throws: If the destination encounters an error.
    func blobExists(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Bool

    /// Uploads a blob of unstructured data.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///       On the wire, all blob uploads are `application/octet-stream'.
    ///   - data: Object to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded blob.
    /// - Throws: If the upload fails.
    func putBlob(
        repository: ImageReference.Repository,
        mediaType: String,
        data: Data
    ) async throws -> ContentDescriptor

    /// Encodes and uploads a JSON object.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///       On the wire, all blob uploads are `application/octet-stream'.
    ///   - data: Object to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded blob.
    /// - Throws: If the blob cannot be encoded or the upload fails.
    ///
    ///  Some JSON objects, such as ImageConfiguration, are stored
    /// in the registry as plain blobs with MIME type "application/octet-stream".
    /// This function encodes the data parameter and uploads it as a generic blob.
    func putBlob<Body: Encodable>(
        repository: ImageReference.Repository,
        mediaType: String,
        data: Body
    ) async throws -> ContentDescriptor

    /// Encodes and uploads an image manifest.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - reference: Optional tag to apply to this manifest.
    ///   - manifest: Manifest to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded blob.
    /// - Throws: If the blob cannot be encoded or the upload fails.
    ///
    /// Manifests are not treated as blobs by the distribution specification.
    /// They have their own MIME types and are uploaded to different
    /// registry endpoints than blobs.
    func putManifest(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)?,
        manifest: ImageManifest
    ) async throws -> ContentDescriptor
}

extension ImageDestination {
    /// Uploads a blob of unstructured data.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///       On the wire, all blob uploads are `application/octet-stream'.
    ///   - data: Object to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded blob.
    /// - Throws: If the upload fails.
    public func putBlob(
        repository: ImageReference.Repository,
        mediaType: String = "application/octet-stream",
        data: Data
    ) async throws -> ContentDescriptor {
        try await putBlob(repository: repository, mediaType: mediaType, data: data)
    }

    /// Upload an image configuration record to the registry.
    /// - Parameters:
    ///   - image: Reference to the image associated with the record.
    ///   - configuration: An image configuration record
    /// - Returns: An `ContentDescriptor` referring to the blob stored in the registry.
    /// - Throws: If the blob upload fails.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function encodes the provided configuration record and stores it as a blob in the registry.
    public func putImageConfiguration(
        forImage image: ImageReference,
        configuration: ImageConfiguration
    ) async throws -> ContentDescriptor {
        try await putBlob(
            repository: image.repository,
            mediaType: "application/vnd.oci.image.config.v1+json",
            data: configuration
        )
    }
}
