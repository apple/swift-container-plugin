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

import struct Foundation.Data

extension RegistryClient: ImageSource {
    /// Fetches an unstructured blob of data from the registry.
    ///
    /// - Parameters:
    ///   - repository: Name of the repository containing the blob.
    ///   - digest: Digest of the blob.
    /// - Returns: The downloaded data.
    /// - Throws: If the blob download fails.
    public func getBlob(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Data {
        try await executeRequestThrowing(
            .get(repository, path: "blobs/\(digest)", accepting: ["application/octet-stream"]),
            decodingErrors: [.notFound]
        )
        .data
    }

    /// Fetches an image manifest.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the manifest to fetch.
    /// - Returns: The downloaded manifest.
    /// - Throws: If the download fails or the manifest cannot be decoded.
    public func getManifest(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> (ImageManifest, ContentDescriptor) {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
        let (data, response) = try await executeRequestThrowing(
            .get(
                repository,
                path: "manifests/\(reference)",
                accepting: [
                    "application/vnd.oci.image.manifest.v1+json",
                    "application/vnd.docker.distribution.manifest.v2+json",
                ]
            ),
            decodingErrors: [.notFound]
        )
        return (
            try decoder.decode(ImageManifest.self, from: data),
            ContentDescriptor(
                mediaType: response.headerFields[.contentType] ?? "application/vnd.oci.image.manifest.v1+json",
                digest: "\(ImageReference.Digest(of: data))",
                size: Int64(data.count)
            )
        )
    }

    /// Fetches an image index.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the index to fetch.
    /// - Returns: The downloaded index.
    /// - Throws: If the download fails or the index cannot be decoded.
    public func getIndex(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> ImageIndex {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
        let (data, _) = try await executeRequestThrowing(
            .get(
                repository,
                path: "manifests/\(reference)",
                accepting: [
                    "application/vnd.oci.image.index.v1+json",
                    "application/vnd.docker.distribution.manifest.list.v2+json",
                ]
            ),
            decodingErrors: [.notFound]
        )
        return try decoder.decode(ImageIndex.self, from: data)
    }

    /// Get an image configuration record from the registry.
    /// - Parameters:
    ///   - image: Reference to the image containing the record.
    ///   - digest: Digest of the record.
    /// - Returns: The image confguration record stored in `repository` with digest `digest`.
    /// - Throws: If the blob cannot be decoded as an `ImageConfiguration`.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function retrieves the requested blob and tries to decode it as a configuration record.
    public func getImageConfiguration(
        forImage image: ImageReference,
        digest: ImageReference.Digest
    ) async throws -> ImageConfiguration {
        let data = try await getBlob(repository: image.repository, digest: digest)
        return try decoder.decode(ImageConfiguration.self, from: data)
    }
}
