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
#endif
import HTTPTypes
import Basics

enum RegistryClientError: Error {
    case registryParseError(String)
    case invalidRegistryPath(String)
    case invalidUploadLocation(String)
}

extension RegistryClientError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .registryParseError(reference): return "Unable to parse registry: \(reference)"
        case let .invalidRegistryPath(path): return "Unable to construct URL for registry path: \(path)"
        case let .invalidUploadLocation(location): return "Received invalid upload location from registry: \(location)"
        }
    }
}

// Connections to localhost, 127.0.0.1 and ::1 are typically allowed to use plain HTTP.
func isLocalRegistry(_ registry: String) -> Bool {
    registry.starts(with: "localhost") || registry.starts(with: "127.0.0.1") || registry.starts(with: "::1")
}

/// RegistryClient handles a connection to container registry.
public struct RegistryClient {
    /// HTTPClient instance used to connect to the registry
    var client: HTTPClient

    /// Registry location
    var registryURL: URL

    /// Authentication handler
    var auth: AuthHandler?

    var encoder: JSONEncoder
    var decoder: JSONDecoder

    /// Creates a new RegistryClient
    /// - Parameters:
    ///   - registry: HTTP URL of the registry's API endpoint.
    ///   - client: HTTPClient object to use to connect to the registry.
    ///   - auth: An authentication handler which can provide authentication credentials.
    ///   - encoder: JSONEncoder to use when encoding messages to the registry.
    ///   - decoder: JSONDecoder to use when decoding messages from the registry.
    /// - Throws: If the registry name is invalid.
    /// - Throws: If a connection to the registry cannot be established.
    public init(
        registry: URL,
        client: HTTPClient,
        auth: AuthHandler? = nil,
        encodingWith encoder: JSONEncoder? = nil,
        decodingWith decoder: JSONDecoder? = nil
    ) async throws {
        registryURL = registry
        self.client = client
        self.auth = auth

        // The registry server does not normalize JSON and calculates digests over the raw message text.
        // We must use consistent encoder settings when encoding and calculating digests.
        //
        // We must also configure the date encoding strategy otherwise the dates are printed as
        // fractional numbers of seconds, whereas the container image requires ISO8601.
        if let encoder {
            self.encoder = encoder
        } else {
            self.encoder = JSONEncoder()
            self.encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            self.encoder.dateEncodingStrategy = .iso8601
        }

        // No special configuration is required for the decoder, but we should use a single instance
        // rather than creating new instances where we need them.
        self.decoder = decoder ?? JSONDecoder()

        // Verify that we can talk to the registry
        _ = try await checkAPI()
    }

    /// Creates a new RegistryClient, constructing a suitable URLSession-based client.
    /// - Parameters:
    ///   - registry: Container registry name.  This is not a conventional URL, and does not include a transport.
    ///   - insecure: If `true`, allow connections to this registry over plaintext HTTP.
    ///   - auth: An authentication handler which can provide authentication credentials.
    /// - Throws: If the registry name is invalid.
    /// - Throws: If a connection to the registry cannot be established.
    public init(registry: String, insecure: Bool = false, auth: AuthHandler? = nil) async throws {
        // The registry reference format must not contain a scheme
        let urlScheme = insecure || isLocalRegistry(registry) ? "http" : "https"
        guard let registryURL = URL(string: "\(urlScheme)://\(registry)") else {
            throw RegistryClientError.registryParseError(registry)
        }

        // URLSessionConfiguration.default allows request and credential caching, making testing confusing.
        // The SwiftPM sandbox also prevents URLSession from writing to the cache, which causes warnings.
        // .ephemeral has no caches.
        let urlsession = URLSession(configuration: .ephemeral)
        try await self.init(registry: registryURL, client: urlsession, auth: auth)
    }

    func registryURLForPath(_ path: String) throws -> URL {
        var components = URLComponents()
        components.path = path
        guard let url = components.url(relativeTo: registryURL) else {
            throw RegistryClientError.invalidRegistryPath(path)
        }
        return url
    }
}

extension RegistryClient {
    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    ///
    /// A plain Data version of this function is required because Data is Decodable and decodes from base64.
    /// Plain blobs are not encoded in the registry, so trying to decode them will fail.
    public func executeRequestThrowing(
        _ request: HTTPRequest,
        expectingStatus success: HTTPResponse.Status = .ok,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        do {
            let authenticatedRequest = auth?.auth(for: request) ?? request
            return try await client.executeRequestThrowing(authenticatedRequest, expectingStatus: success)
        } catch HTTPClientError.authenticationChallenge(let challenge, let request, let response) {
            guard
                let authenticatedRequest = try await auth?
                    .auth(for: request, withChallenge: challenge, usingClient: client)
            else { throw HTTPClientError.unauthorized(request: request, response: response) }
            return try await client.executeRequestThrowing(authenticatedRequest, expectingStatus: success)
        } catch HTTPClientError.unexpectedStatusCode(let status, _, let .some(responseData))
            where errors.contains(status)
        {
            let decoded = try decoder.decode(DistributionErrors.self, from: responseData)
            throw decoded
        }
    }

    /// Execute an HTTP request with no request body, decoding the JSON response
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing<Response: Decodable>(
        _ request: HTTPRequest,
        expectingStatus success: HTTPResponse.Status = .ok,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Response, response: HTTPResponse) {
        let (data, httpResponse) = try await executeRequestThrowing(
            request,
            expectingStatus: success,
            decodingErrors: errors
        )
        let decoded = try decoder.decode(Response.self, from: data)
        return (decoded, httpResponse)
    }

    /// Execute an HTTP request uploading a request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    ///
    /// A plain Data version of this function is required because Data is Encodable and encodes to base64.
    /// Accidentally encoding data blobs will cause digests to fail and runtimes to be unable to run the images.
    public func executeRequestThrowing(
        _ request: HTTPRequest,
        uploading payload: Data,
        expectingStatus success: HTTPResponse.Status,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        do {
            let authenticatedRequest = auth?.auth(for: request) ?? request
            return try await client.executeRequestThrowing(
                authenticatedRequest,
                uploading: payload,
                expectingStatus: success
            )
        } catch HTTPClientError.authenticationChallenge(let challenge, let request, let response) {
            guard
                let authenticatedRequest = try await auth?
                    .auth(for: request, withChallenge: challenge, usingClient: client)
            else { throw HTTPClientError.unauthorized(request: request, response: response) }
            return try await client.executeRequestThrowing(
                authenticatedRequest,
                uploading: payload,
                expectingStatus: success
            )
        } catch HTTPClientError.unexpectedStatusCode(let status, _, let .some(responseData))
            where errors.contains(status)
        {
            let decoded = try decoder.decode(DistributionErrors.self, from: responseData)
            throw decoded
        }
    }

    /// Execute an HTTP request uploading a Codable request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing<Body: Encodable>(
        _ request: HTTPRequest,
        uploading payload: Body,
        expectingStatus success: HTTPResponse.Status,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        try await executeRequestThrowing(
            request,
            uploading: try encoder.encode(payload),
            expectingStatus: success,
            decodingErrors: errors
        )
    }
}

/// Make decoded registry errors throwable
extension DistributionErrors: Error {}
