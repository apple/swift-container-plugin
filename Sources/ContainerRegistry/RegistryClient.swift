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
    var authChallenge: AuthChallenge

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
        self.authChallenge = try await RegistryClient.checkAPI(client: self.client, registryURL: self.registryURL)
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
}

extension URL {
    /// The base distribution endpoint URL
    var distributionEndpoint: URL { self.appendingPathComponent("/v2/") }

    /// The URL for a particular endpoint relating to a particular repository
    /// - Parameters:
    ///   - repository: The name of the repository.   May include path separators.
    ///   - endpoint: The distribution endpoint e.g. "tags/list"
    /// - Returns: A fully-qualified URL for the endpoint.
    func distributionEndpoint(forRepository repository: String, andEndpoint endpoint: String) -> URL {
        self.appendingPathComponent("/v2/\(repository)/\(endpoint)")
    }
}

extension RegistryClient {
    /// Represents an operation to be executed on the registry.
    struct RegistryOperation {
        enum Destination {
            case subpath(String)  // Repository subpath on the registry
            case url(URL)  // Full destination URL, for example from a Location header returned by the registry
        }

        var method: HTTPRequest.Method  // HTTP method
        var repository: String  // Repository path on the registry
        var destination: Destination  // Destination of the operation: can be a subpath or remote URL
        var actions: [String]  // Actions required by this operation
        var accepting: [String] = []  // Acceptable response types
        var contentType: String? = nil  // Request data type

        func url(relativeTo registry: URL) -> URL {
            switch destination {
            case .url(let url): return url
            case .subpath(let path): return registry.distributionEndpoint(forRepository: repository, andEndpoint: path)
            }
        }

        // Convenience constructors
        static func get(
            _ repository: String,
            path: String,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .get,
                repository: repository,
                destination: .subpath(path),
                actions: ["pull"],
                accepting: accepting,
                contentType: contentType
            )
        }

        static func get(
            _ repository: String,
            url: URL,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .get,
                repository: repository,
                destination: .url(url),
                actions: ["pull"],
                accepting: accepting,
                contentType: contentType
            )
        }

        static func head(
            _ repository: String,
            path: String,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .head,
                repository: repository,
                destination: .subpath(path),
                actions: ["pull"],
                accepting: accepting,
                contentType: contentType
            )
        }

        /// This handles the 'put' case where the registry gives us a location URL which we must not alter, aside from adding the digest to it
        static func put(
            _ repository: String,
            url: URL,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .put,
                repository: repository,
                destination: .url(url),
                actions: ["push", "pull"],
                accepting: accepting,
                contentType: contentType
            )
        }

        static func put(
            _ repository: String,
            path: String,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .put,
                repository: repository,
                destination: .subpath(path),
                actions: ["push", "pull"],
                accepting: accepting,
                contentType: contentType
            )
        }

        static func post(
            _ repository: String,
            path: String,
            actions: [String]? = nil,
            accepting: [String] = [],
            contentType: String? = nil
        ) -> RegistryOperation {
            .init(
                method: .post,
                repository: repository,
                destination: .subpath(path),
                actions: ["push", "pull"],
                accepting: accepting,
                contentType: contentType
            )
        }
    }

    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - operation: The Registry operation to execute.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    ///
    /// A plain Data version of this function is required because Data is Decodable and decodes from base64.
    /// Plain blobs are not encoded in the registry, so trying to decode them will fail.
    func executeRequestThrowing(
        _ operation: RegistryOperation,
        expectingStatus success: HTTPResponse.Status = .ok,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        let authorization = try await auth?
            .auth(
                registry: registryURL,
                repository: operation.repository,
                actions: operation.actions,
                withScheme: authChallenge,
                usingClient: client
            )

        let request = HTTPRequest(
            method: operation.method,
            url: operation.url(relativeTo: registryURL),
            accepting: operation.accepting,
            contentType: operation.contentType,
            withAuthorization: authorization
        )

        do {
            return try await client.executeRequestThrowing(request, expectingStatus: success)
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
    func executeRequestThrowing<Response: Decodable>(
        _ request: RegistryOperation,
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
    ///   - operation: The Registry operation to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    ///
    /// A plain Data version of this function is required because Data is Encodable and encodes to base64.
    /// Accidentally encoding data blobs will cause digests to fail and runtimes to be unable to run the images.
    func executeRequestThrowing(
        _ operation: RegistryOperation,
        uploading payload: Data,
        expectingStatus success: HTTPResponse.Status,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        let authorization = try await auth?
            .auth(
                registry: registryURL,
                repository: operation.repository,
                actions: operation.actions,
                withScheme: authChallenge,
                usingClient: client
            )

        let request = HTTPRequest(
            method: operation.method,
            url: operation.url(relativeTo: registryURL),
            accepting: operation.accepting,
            contentType: operation.contentType,
            withAuthorization: authorization
        )

        do {
            return try await client.executeRequestThrowing(request, uploading: payload, expectingStatus: success)
        } catch HTTPClientError.unexpectedStatusCode(let status, _, let .some(responseData))
            where errors.contains(status)
        {
            let decoded = try decoder.decode(DistributionErrors.self, from: responseData)
            throw decoded
        }
    }

    /// Execute an HTTP request uploading a Codable request body.
    /// - Parameters:
    ///   - operation: The Registry operation to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func executeRequestThrowing<Body: Encodable>(
        _ operation: RegistryOperation,
        uploading payload: Body,
        expectingStatus success: HTTPResponse.Status,
        decodingErrors errors: [HTTPResponse.Status]
    ) async throws -> (data: Data, response: HTTPResponse) {
        try await executeRequestThrowing(
            operation,
            uploading: try encoder.encode(payload),
            expectingStatus: success,
            decodingErrors: errors
        )
    }
}

/// Make decoded registry errors throwable
extension DistributionErrors: Error {}
