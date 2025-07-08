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
    func getTags(repository: ImageReference.Repository) async throws -> Tags {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-tags
        let (data, _) = try await executeRequestThrowing(
            .get(repository, path: "tags/list"),
            decodingErrors: [.notFound]
        )
        return try decoder.decode(Tags.self, from: data)
    }
}
