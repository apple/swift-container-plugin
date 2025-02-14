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
import struct Crypto.SHA256

/// Calculates the digest of a blob of data.
/// - Parameter data: Blob of data to digest.
/// - Returns: The blob's digest, in the format expected by the distribution protocol.
public func digest<D: DataProtocol>(of data: D) -> String {
    // SHA256 is required; some registries might also support SHA512
    let hash = SHA256.hash(data: data)
    let digest = hash.compactMap { String(format: "%02x", $0) }.joined()
    return "sha256:" + digest
}

extension RegistryClient {
    // Internal helper method to initiate a blob upload in 'two shot' mode
    func startBlobUploadSession(repository: String) async throws -> URL {
        precondition(repository.count > 0, "repository must not be an empty string")

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

// The spec says that Docker- prefix headers are no longer to be used, but also specifies that the registry digest is returned in this header.
extension HTTPField.Name { static let dockerContentDigest = Self("Docker-Content-Digest")! }

public extension RegistryClient {
    func blobExists(repository: String, digest: String) async throws -> Bool {
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(digest.count > 0)

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
    func getBlob(repository: String, digest: String) async throws -> Data {
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(digest.count > 0, "digest must not be an empty string")

        return try await executeRequestThrowing(
            .get(repository, path: "blobs/\(digest)", accepting: ["application/octet-stream"]),
            decodingErrors: [.notFound]
        )
        .data
    }

    /// Fetches a blob and tries to decode it as a JSON object.
    ///
    /// - Parameters:
    ///   - repository: Name of the repository containing the blob.
    ///   - digest: Digest of the blob.
    /// - Returns: The decoded object.
    /// - Throws: If the blob download fails or the blob cannot be decoded.
    ///
    /// Some JSON objects, such as ImageConfiguration, are stored
    /// in the registry as plain blobs with MIME type "application/octet-stream".
    /// This function attempts to decode the received data without reference
    /// to the MIME type.
    func getBlob<Response: Decodable>(repository: String, digest: String) async throws -> Response {
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(digest.count > 0, "digest must not be an empty string")

        return try await executeRequestThrowing(
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
    func putBlob(repository: String, mediaType: String = "application/octet-stream", data: Data) async throws
        -> ContentDescriptor
    {
        precondition(repository.count > 0, "repository must not be an empty string")

        // Ask the server to open a session and tell us where to upload our data
        let location = try await startBlobUploadSession(repository: repository)

        // Append the digest to the upload location, as the specification requires.
        // The server's URL is arbitrary and might already contain query items which we must not overwrite.
        // The URL could even point to a different host.
        let digest = digest(of: data)
        let uploadURL = location.appending(queryItems: [.init(name: "digest", value: "\(digest.utf8)")])

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
            assert(digest == serverDigest)
        }
        return .init(mediaType: mediaType, digest: digest, size: Int64(data.count))
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
    func putBlob<Body: Encodable>(repository: String, mediaType: String = "application/octet-stream", data: Body)
        async throws -> ContentDescriptor
    {
        let encoded = try encoder.encode(data)
        return try await putBlob(repository: repository, mediaType: mediaType, data: encoded)
    }
}
