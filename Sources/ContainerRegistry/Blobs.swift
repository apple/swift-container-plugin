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

public extension RegistryClient {
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
}
