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

public extension RegistryClient {
    func putManifest(repository: String, reference: String, manifest: ImageManifest) async throws -> String {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pushing-manifests
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(reference.count > 0, "reference must not be an empty string")

        let httpResponse = try await executeRequestThrowing(
            // All blob uploads have Content-Type: application/octet-stream on the wire, even if mediatype is different
            .put(
                registryURLForPath("/v2/\(repository)/manifests/\(reference)"),
                contentType: manifest.mediaType ?? "application/vnd.oci.image.manifest.v1+json"
            ),
            uploading: manifest,
            expectingStatus: .created,
            decodingErrors: [.notFound]
        )

        guard let location = httpResponse.response.headerFields[.location] else {
            throw HTTPClientError.missingResponseHeader("Location")
        }
        return location
    }

    func getManifest(repository: String, reference: String) async throws -> ImageManifest {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(reference.count > 0, "reference must not be an empty string")

        return try await executeRequestThrowing(
            .get(
                registryURLForPath("/v2/\(repository)/manifests/\(reference)"),
                accepting: [
                    "application/vnd.oci.image.manifest.v1+json",
                    "application/vnd.docker.distribution.manifest.v2+json",
                ]
            ),
            decodingErrors: [.notFound]
        )
        .data
    }

    func getIndex(repository: String, reference: String) async throws -> ImageIndex {
        precondition(repository.count > 0, "repository must not be an empty string")
        precondition(reference.count > 0, "reference must not be an empty string")

        return try await executeRequestThrowing(
            .get(
                registryURLForPath("/v2/\(repository)/manifests/\(reference)"),
                accepting: [
                    "application/vnd.oci.image.index.v1+json",
                    "application/vnd.docker.distribution.manifest.list.v2+json",
                ]
            ),
            decodingErrors: [.notFound]
        )
        .data
    }
}
