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

extension RegistryClient {
    /// Get an image configuration record from the registry.
    /// - Parameters:
    ///   - image: Reference to the image containing the record.
    ///   - digest: Digest of the record.
    /// - Returns: The image confguration record stored in `repository` with digest `digest`.
    /// - Throws: If the blob cannot be decoded as an `ImageConfiguration`.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function retrieves the requested blob and tries to decode it as a configuration record.
    public func getImageConfiguration(forImage image: ImageReference, digest: String) async throws -> ImageConfiguration
    {
        try await getBlob(repository: image.repository, digest: digest)
    }

    /// Upload an image configuration record to the registry.
    /// - Parameters:
    ///   - image: Reference to the image associated with the record.
    ///   - configuration: An image configuration record
    /// - Returns: An `ContentDescriptor` referring to the blob stored in the registry.
    /// - Throws: If the blob upload fails.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function encodes the provided configuration record and stores it as a blob in the registry.
    public func putImageConfiguration(forImage image: ImageReference, configuration: ImageConfiguration) async throws
        -> ContentDescriptor
    {
        try await putBlob(
            repository: image.repository,
            mediaType: "application/vnd.oci.image.config.v1+json",
            data: configuration
        )
    }
}
