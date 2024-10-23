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

public extension RegistryClient {
    /// Checks whether the registry supports v2 of the distribution specification.
    /// - Returns: an `true` if the registry supports the distribution specification.
    /// - Throws: if the registry does not support the distribution specification.
    static func checkAPI(client: HTTPClient, registryURL: URL) async throws -> AuthChallenge {
        // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#determining-support

        // The registry indicates that it supports the v2 protocol by returning a 200 OK response.
        // Many registries also set `Content-Type: application/json` and return empty JSON objects,
        // but this is not required and some do not.
        // The registry may require authentication on this endpoint.

        do {
            // Using the bare HTTP client because this is the only endpoint which does not include a repository path
            // and to avoid RegistryClient's auth handling
            let _ = try await client.executeRequestThrowing(
                .get(registryURL.distributionEndpoint, withAuthorization: nil),
                expectingStatus: .ok
            )
            return .none

        } catch HTTPClientError.authenticationChallenge(let challenge, _, _) { return .init(challenge: challenge) }
    }
}
