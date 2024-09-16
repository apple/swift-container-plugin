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
    /// Returns a boolean value indicating whether the registry supports v2 of the distribution specification.
    /// - Returns: `true` if the registry supports the distribution specification, otherwise `false`.
    func checkAPI() async throws -> Bool {
        // The registry indicates that it supports the v2 protocol by returning an empty JSON object i.e. {}.
        // The registry may require authentication on this endpoint.
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#determining-support
        do {
            return try await executeRequestThrowing(.get(registryURLForPath("/v2/")), decodingErrors: [401, 404]).data
                == EmptyObject()
        } catch HTTPClientError.unexpectedStatusCode(status: 404, _, _) { return false }
    }
}
