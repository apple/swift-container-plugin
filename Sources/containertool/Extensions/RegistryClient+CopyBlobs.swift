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

import ContainerRegistry

extension RegistryClient {
    /// Copies a blob from another registry to this one.
    /// - Parameters:
    ///   - digest: The digest of the blob to copy.
    ///   - sourceRepository: The repository from which the blob should be copied.
    ///   - destClient: The client to which the blob should be copied.
    ///   - destRepository: The repository on this registry to which the blob should be copied.
    /// - Throws: If the copy cannot be completed.
    func copyBlob(
        digest: ImageReference.Digest,
        fromRepository sourceRepository: ImageReference.Repository,
        toClient destClient: ImageDestination,
        toRepository destRepository: ImageReference.Repository
    ) async throws {
        if try await destClient.blobExists(repository: destRepository, digest: digest) {
            log("Layer \(digest): already exists")
            return
        }

        log("Layer \(digest): fetching")
        let blob = try await getBlob(repository: sourceRepository, digest: digest)

        log("Layer \(digest): pushing")
        let uploaded = try await destClient.putBlob(repository: destRepository, data: blob)
        log("Layer \(digest): done")

        guard "\(digest)" == uploaded.digest else {
            throw RegistryClientError.digestMismatch(expected: "\(digest)", registry: uploaded.digest)
        }
    }
}
