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
import ContainerRegistry

extension RegistryClient {
    func getImageManifest(repository: String, reference: String, architecture: String) async throws -> ImageManifest {
        // We pushed the amd64 tag but it points to a single-architecture index, not directly to a manifest
        // if we get an index we should get a manifest, otherwise we might get a manifest directly

        do {
            // Try to retrieve a manifest.   If the object with this reference is actually an index, the content-type will not match and
            // an error will be thrown.
            return try await getManifest(repository: repository, reference: reference)
        } catch {
            // Try again, treating the top level object as an index.
            // This could be more efficient if the exception thrown by getManfiest() included the data it was unable to parse
            let index = try await getIndex(repository: repository, reference: reference)
            guard let manifest = index.manifests.first(where: { $0.platform?.architecture == architecture }) else {
                throw "Could not find a suitable base image for \(architecture)"
            }
            // The index should not point to another index;   if it does, this call will throw a final error to be handled by the caller.
            return try await getManifest(repository: repository, reference: manifest.digest)
        }
    }

    // A layer is a tarball, optionally compressed using gzip or zstd
    // See https://github.com/opencontainers/image-spec/blob/main/media-types.md
    func uploadImageLayer(
        repository: String,
        layer: Data,
        mediaType: String = "application/vnd.oci.image.layer.v1.tar+gzip"
    ) async throws -> ContentDescriptor {
        // The layer blob is the gzipped tarball
        let blob = Data(gzip([UInt8](layer)))
        log("Uploading application layer")
        return try await putBlob(repository: repository, mediaType: mediaType, data: blob)
    }
}
