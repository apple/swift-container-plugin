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
    func putManifest(
        repository: ImageReference.Repository,
        reference: (any ImageReference.Reference)? = nil,
        manifest: ImageManifest
    ) async throws -> ContentDescriptor {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pushing-manifests

        let encoded = try encoder.encode(manifest)
        let digest = digest(of: encoded)
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

    func getManifest(
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
                digest: "\(digest(of: data))",
                size: Int64(data.count)
            )
        )
    }

    func getIndex(
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
}
