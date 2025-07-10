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

/// A source, such as a registry, from which container images can be fetched.
public protocol ImageSource {
    /// Fetches a blob of unstructured data.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - digest: Digest of the blob.
    /// - Returns: The downloaded data.
    /// - Throws: If the blob download fails.
    func getBlob(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Data

    /// Fetches an image manifest.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the manifest to fetch.
    /// - Returns: The downloaded manifest.
    /// - Throws: If the download fails or the manifest cannot be decoded.
    func getManifest(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> (ImageManifest, ContentDescriptor)

    /// Fetches an image index.
    ///
    /// - Parameters:
    ///   - repository: Name of the source repository.
    ///   - reference: Tag or digest of the index to fetch.
    /// - Returns: The downloaded index.
    /// - Throws: If the download fails or the index cannot be decoded.
    func getIndex(
        repository: ImageReference.Repository,
        reference: any ImageReference.Reference
    ) async throws -> ImageIndex

    /// Fetches an image configuration from the registry.
    ///
    /// - Parameters:
    ///   - image: Reference to the image containing the record.
    ///   - digest: Digest of the configuration object to fetch.
    /// - Returns: The image confguration record.
    /// - Throws: If the download fails or the configuration record cannot be decoded.
    ///
    /// Image configuration records are stored as blobs in the registry.  This function retrieves
    /// the requested blob and tries to decode it as a configuration record.
    func getImageConfiguration(
        forImage image: ImageReference,
        digest: ImageReference.Digest
    ) async throws -> ImageConfiguration
}
