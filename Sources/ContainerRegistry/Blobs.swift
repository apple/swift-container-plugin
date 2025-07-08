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

import Foundation
import HTTPTypes

extension RegistryClient {
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
}

public extension RegistryClient {
    func blobExists(repository: ImageReference.Repository, digest: ImageReference.Digest) async throws -> Bool {
        do {
            let _ = try await executeRequestThrowing(
                .head(repository, path: "blobs/\(digest)"),
                decodingErrors: [.notFound]
            )
            return true
        } catch HTTPClientError.unexpectedStatusCode(status: .notFound, _, _) { return false }
    }

    /// Fetches an unstructured blob of data from the registry.
    ///
    /// - Parameters:
    ///   - repository: Name of the repository containing the blob.
    ///   - digest: Digest of the blob.
    /// - Returns: The downloaded data.
    /// - Throws: If the blob download fails.
    func getBlob(repository: ImageReference.Repository, digest: ImageReference.Digest) async throws -> Data {
        try await executeRequestThrowing(
            .get(repository, path: "blobs/\(digest)", accepting: ["application/octet-stream"]),
            decodingErrors: [.notFound]
        )
        .data
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
    func putBlob(repository: ImageReference.Repository, mediaType: String = "application/octet-stream", data: Data)
        async throws
        -> ContentDescriptor
    {
        // Ask the server to open a session and tell us where to upload our data
        let location = try await startBlobUploadSession(repository: repository)

        // Append the digest to the upload location, as the specification requires.
        // The server's URL is arbitrary and might already contain query items which we must not overwrite.
        // The URL could even point to a different host.
        let digest = digest(of: data)
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
    func putBlob<Body: Encodable>(
        repository: ImageReference.Repository,
        mediaType: String = "application/octet-stream",
        data: Body
    )
        async throws -> ContentDescriptor
    {
        let encoded = try encoder.encode(data)
        return try await putBlob(repository: repository, mediaType: mediaType, data: encoded)
    }
}
