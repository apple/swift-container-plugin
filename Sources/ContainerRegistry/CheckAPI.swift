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
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#determining-support
        // The registry indicates that it supports the v2 protocol by returning a 200 OK response.
        // Many registries also set `Content-Type: application/json` and return empty JSON objects,
        // but this is not required and some do not.
        // The registry may require authentication on this endpoint.
        do {
            let _ = try await executeRequestThrowing(
                .get(registryURLForPath("/v2/")),
                decodingErrors: [.unauthorized, .notFound]
            )
            return true
        } catch HTTPClientError.unexpectedStatusCode(status: .notFound, _, _) { return false }
    }
}
