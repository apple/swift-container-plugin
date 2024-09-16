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
#if canImport(FoundationNetworking)
import FoundationNetworking

extension URLSession {
    /// Uploads data to a URL based on the specified URL request and delivers the result asynchronously.
    /// - Parameters:
    ///   - request: A URL request object that provides request-specific information such as the URL, cache policy, request type, and body data or body stream.
    ///   - bodyData: The body data for the request.
    /// - Returns: An asynchronously-delivered tuple that contains any data returned by the server as a Data instance, and a URLResponse.
    /// - Throws: If the underlying HTTP transport fails.
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            uploadTask(with: request, from: bodyData) { data, response, error in
                if let error {
                    continuation.resume(with: .failure(error))
                    return
                }

                // If the transport failed, we should have an error.
                // If the transport succeeded, but the server sent an error, we should have a response with an error code.
                // It's not clear how both error and response could be nil at the same time.
                guard let response else {
                    continuation.resume(throwing: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
                    return
                }

                continuation.resume(with: .success((data ?? Data(), response)))
            }
            .resume()
        }
    }

    /// Downloads data from a URL based on the specified URL request and delivers the result asynchronously.
    /// - Parameter:
    ///   - request: A URL request object that provides request-specific information such as the URL, cache policy, and request type.
    /// - Returns: An asynchronously-delivered tuple that contains any data returned by the server as a Data instance, and a URLResponse.
    /// - Throws: If the underlying HTTP transport fails.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(with: .failure(error))
                    return
                }

                // If the transport failed, we should have an error.
                // If the transport succeeded, but the server sent an error, we should have a response with an error code.
                // It's not clear how both error and response could be nil at the same time.
                guard let response else {
                    continuation.resume(throwing: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
                    return
                }

                continuation.resume(with: .success((data ?? Data(), response)))
            }
            .resume()
        }
    }
}
#endif
