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
import struct Foundation.URL
import HTTPTypes

extension RegistryClient: ImageDestination {
    // Internal helper method to initiate a blob upload in 'two shot' mode
    func startBlobUploadSession(repository: ImageReference.Repository) async throws -> URL {
        // Upload in "two shot" mode.
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#post-then-put
        // - POST to obtain a session ID.
        // - Do not include the digest.
        // Response will include a 'Location' header telling us where to PUT the blob data.
        let httpResponse = try await executeRequestThrowing(
            .post(repository, path: "blobs/uploads/"),
            expectingStatus: .accepted,  // expected response code for a "two-shot" upload
            decodingErrors: [.notFound]
        )

        guard let location = httpResponse.response.headerFields[.location] else {
            throw HTTPClientError.missingResponseHeader("Location")
        }

        guard let locationURL = URL(string: location) else {
            throw RegistryClientError.invalidUploadLocation("\(location)")
        }

        // The location may be either an absolute URL or a relative URL
        // If it is relative we need to make it absolute
        guard locationURL.host != nil else {
            guard let absoluteURL = URL(string: location, relativeTo: registryURL) else {
                throw RegistryClientError.invalidUploadLocation("\(location)")
            }
            return absoluteURL
        }

        return locationURL
    }

    /// Checks whether a blob exists.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - digest: Digest of the requested blob.
    /// - Returns: True if the blob exists, otherwise false.
    /// - Throws: If the destination encounters an error.
    public func blobExists(
        repository: ImageReference.Repository,
        digest: ImageReference.Digest
    ) async throws -> Bool {
        do {
            let _ = try await executeRequestThrowing(
                .head(repository, path: "blobs/\(digest)"),
                decodingErrors: [.notFound]
            )
            return true
        } catch HTTPClientError.unexpectedStatusCode(status: .notFound, _, _) { return false }
    }

    /// Uploads a blob to the registry.
    ///
    /// This function uploads a blob of unstructured data to the registry.
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - mediaType: mediaType field for returned ContentDescriptor.
    ///       On the wire, all blob uploads are `application/octet-stream'.
    ///   - data: Object to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded blob.
    /// - Throws: If the blob cannot be encoded or the upload fails.
    public func putBlob(
        repository: ImageReference.Repository,
        mediaType: String = "application/octet-stream",
        data: Data
    ) async throws -> ContentDescriptor {
        // Ask the server to open a session and tell us where to upload our data
        let location = try await startBlobUploadSession(repository: repository)

        // Append the digest to the upload location, as the specification requires.
        // The server's URL is arbitrary and might already contain query items which we must not overwrite.
        // The URL could even point to a different host.
        let digest = ImageReference.Digest(of: data)
        let uploadURL = location.appending(queryItems: [.init(name: "digest", value: "\(digest)")])

        let httpResponse = try await executeRequestThrowing(
            // All blob uploads have Content-Type: application/octet-stream on the wire, even if mediatype is different
            .put(repository, url: uploadURL, contentType: "application/octet-stream"),
            uploading: data,
            expectingStatus: .created,
            decodingErrors: [.badRequest, .notFound]
        )

        // The registry could compute a different digest and we should use its value
        // as the canonical digest for linking blobs.   If the registry sends a digest we
        // should check that it matches our locally-calculated digest.
        if let serverDigest = httpResponse.response.headerFields[.dockerContentDigest] {
            assert("\(digest)" == serverDigest)
        }
        return .init(mediaType: mediaType, digest: "\(digest)", size: Int64(data.count))
    }

    /// Uploads a blob to the registry.
    ///
    /// This function converts an encodable blob to an `application/octet-stream',
    /// calculates its digest and uploads it to the registry.
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
    public func putBlob<Body: Encodable>(
        repository: ImageReference.Repository,
        mediaType: String = "application/octet-stream",
        data: Body
    ) async throws -> ContentDescriptor {
        let encoded = try encoder.encode(data)
        return try await putBlob(repository: repository, mediaType: mediaType, data: encoded)
    }

    /// Encodes and uploads an image manifest.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - reference: Optional tag to apply to this manifest.
    ///   - manifest: Manifest to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded manifest.
    /// - Throws: If the manifest cannot be encoded or the upload fails.
    ///
    /// Manifests are not treated as blobs by the distribution specification.
    /// They have their own MIME types and are uploaded to different
    public func putManifest(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)? = nil,
        manifest: ImageManifest
    ) async throws -> ContentDescriptor {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pushing-manifests

        let encoded = try encoder.encode(manifest)
        let digest = ImageReference.Digest(of: encoded)
        let mediaType = manifest.mediaType ?? "application/vnd.oci.image.manifest.v1+json"

        let _ = try await executeRequestThrowing(
            .put(
                repository,
                path: "manifests/\(reference ?? digest)",
                contentType: mediaType
            ),
            uploading: encoded,
            expectingStatus: .created,
            decodingErrors: [.notFound]
        )

        return ContentDescriptor(
            mediaType: mediaType,
            digest: "\(digest)",
            size: Int64(encoded.count)
        )
    }

    /// Encodes and uploads an image index.
    ///
    /// - Parameters:
    ///   - repository: Name of the destination repository.
    ///   - reference: Optional tag to apply to this index.
    ///   - index: Index to be uploaded.
    /// - Returns: An ContentDescriptor object representing the
    ///            uploaded index.
    /// - Throws: If the index cannot be encoded or the upload fails.
    ///
    /// An index is a type of manifest.   Manifests are not treated as blobs
    /// by the distribution specification.   They have their own MIME types
    /// and are uploaded to different endpoint.
    public func putIndex(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)? = nil,
        index: ImageIndex
    ) async throws -> ContentDescriptor {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pushing-manifests

        let encoded = try encoder.encode(index)
        let digest = ImageReference.Digest(of: encoded)
        let mediaType = index.mediaType ?? "application/vnd.oci.image.index.v1+json"

        let _ = try await executeRequestThrowing(
            .put(
                repository,
                path: "manifests/\(reference ?? digest)",
                contentType: mediaType
            ),
            uploading: encoded,
            expectingStatus: .created,
            decodingErrors: [.notFound]
        )

        return ContentDescriptor(
            mediaType: mediaType,
            digest: "\(digest)",
            size: Int64(encoded.count)
        )
    }
}
