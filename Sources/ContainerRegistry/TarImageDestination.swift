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
import class Foundation.OutputStream
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import Tar

/// A tar file on disk, to which a container image can be saved.
public class TarImageDestination {
    public var decoder: JSONDecoder
    var encoder: JSONEncoder

    var archive: Archive

    /// Creates a new TarImageDestination
    /// - Parameter stream: OutputStream to which the archive should be written
    /// - Throws: If an error occurs when serializing archive.
    public init(toStream stream: OutputStream) throws {
        self.archive = Archive(toStream: stream)
        self.decoder = JSONDecoder()
        self.encoder = containerJSONEncoder()

        try archive.appendFile(name: "oci-layout", data: [UInt8](encoder.encode(ImageLayoutHeader())))
        try archive.appendDirectory(name: "blobs")
        try archive.appendDirectory(name: "blobs/sha256")
    }
}

extension TarImageDestination: ImageDestination {
    /// Saves a blob of unstructured data to the destination.
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///   - data: Object to be saved.
    /// - Returns: An ContentDescriptor object representing the
    ///            saved blob.
    /// - Throws: If the blob cannot be encoded or the save fails.
    public func putBlob(
        repository: ImageReference.Repository,
        mediaType: String,
        data: Data
    ) async throws -> ContentDescriptor {
        let digest = ImageReference.Digest(of: Data(data))
        try archive.appendFile(name: "\(digest.value)", prefix: "blobs/\(digest.algorithm)", data: [UInt8](data))
        return .init(mediaType: mediaType, digest: "\(digest)", size: Int64(data.count))
    }

    /// Saves a JSON object to the destination, serialized as an unstructured blob.
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///   - data: Object to be saved.
    /// - Returns: An ContentDescriptor object representing the
    ///            saved blob.
    /// - Throws: If the blob cannot be encoded or the save fails.
    public func putBlob<Body: Encodable>(
        repository: ImageReference.Repository,
        mediaType: String,
        data: Body
    ) async throws -> ContentDescriptor {
        let encoded = try encoder.encode(data)
        return try await putBlob(repository: repository, mediaType: mediaType, data: encoded)
    }

    /// Checks whether a blob exists.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - digest: Digest of the requested blob.
    /// - Returns: Always returns False.
    /// - Throws: If the destination encounters an error.
    public func blobExists(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Bool {
        false
    }

    /// Encodes and saves an image manifest.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - reference: Optional tag to apply to this manifest.
    ///   - manifest: Manifest to be saved.
    /// - Returns: An ContentDescriptor object representing the
    ///            saved blob.
    /// - Throws: If the blob cannot be encoded or saved.
    public func putManifest(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)?,
        manifest: ImageManifest
    ) async throws -> ContentDescriptor {
        // Manifests are not special in the on-disk representation - they are just stored as blobs
        try await self.putBlob(
            repository: repository,
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            data: manifest
        )
    }

    /// Encodes and saves an image index.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - reference: Optional tag to apply to this index.
    ///   - index: Index to be saved.
    /// - Returns: An ContentDescriptor object representing the
    ///            saved index.
    /// - Throws: If the index cannot be encoded or saving fails.
    public func putIndex(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)?,
        index: ImageIndex
    ) async throws -> ContentDescriptor {
        // Unlike Manifest, Index is not written as a blob
        let encoded = try encoder.encode(index)
        let digest = ImageReference.Digest(of: encoded)
        let mediaType = index.mediaType ?? "application/vnd.oci.image.index.v1+json"

        try archive.appendFile(name: "index.json", data: [UInt8](encoded))

        try archive.appendFile(name: "\(digest.value)", prefix: "blobs/\(digest.algorithm)", data: [UInt8](encoded))
        return .init(mediaType: mediaType, digest: "\(digest)", size: Int64(encoded.count))
    }
}

struct ImageLayoutHeader: Codable {
    var imageLayoutVersion: String = "1.0.0"
}
