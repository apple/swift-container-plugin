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

/// An error encountered while communicating with a container registry.
public enum RegistryClientError: Error {
    case registryParseError(String)
    case invalidRegistryPath(String)
    case invalidUploadLocation(String)
    case invalidDigestAlgorithm(String)
    case digestMismatch(expected: String, registry: String)
    case unexpectedRegistryResponse(status: Int, body: String)
}

extension RegistryClientError: CustomStringConvertible {
    /// Human-readable description of a RegistryClientError
    public var description: String {
        switch self {
        case let .registryParseError(reference): return "Unable to parse registry: \(reference)"
        case let .invalidRegistryPath(path): return "Unable to construct URL for registry path: \(path)"
        case let .invalidUploadLocation(location): return "Received invalid upload location from registry: \(location)"
        case let .invalidDigestAlgorithm(digest): return "Invalid or unsupported digest algorithm: \(digest)"
        case let .digestMismatch(expected, registry):
            return "Digest mismatch: expected \(expected), registry sent \(registry)"
        case let .unexpectedRegistryResponse(status, body):
            return "Registry returned HTTP \(status): \(body)"
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
    /// - Throws: If the registry name is invalid.
    /// - Throws: If a connection to the registry cannot be established.
    public init(
        registry: URL,
        client: HTTPClient,
        auth: AuthHandler? = nil
    ) async throws {
        registryURL = registry
        self.client = client
        self.auth = auth

        // The registry server does not normalize JSON and calculates digests over the raw message text.
        // We must use consistent encoder settings when encoding and calculating digests.
        self.encoder = containerJSONEncoder()
        self.decoder = JSONDecoder()

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
        // A delegate is needed to remove the Authorization header when following HTTP redirects on Linux.
        let urlsession = URLSession(
            configuration: .ephemeral,
            delegate: RegistryURLSessionDelegate(),
            delegateQueue: nil
        )
        try await self.init(registry: registryURL, client: urlsession, auth: auth)
    }
}

final class RegistryURLSessionDelegate: NSObject {}

extension RegistryURLSessionDelegate: URLSessionDelegate, URLSessionTaskDelegate {
    /// Called if the RegistryClient receives an HTTP redirect from the registry.
    /// - Parameters:
    ///   - session: The session containing the task whose request resulted in a redirect.
    ///   - task: The task whose request resulted in a redirect.
    ///   - response: An object containing the server’s response to the original request.
    ///   - request: A URL request object filled out with the new location.
    ///   - completionHandler: A block that your handler should call with either the value
    ///     of the request parameter, a modified URL request object, or NULL to refuse the
    ///     redirect and return the body of the redirect response.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Swift.Void
    ) {
        // The Authorization header should be removed when following a redirect:
        //
        //   https://fetch.spec.whatwg.org/#http-redirect-fetch
        //
        // URLSession on macOS does this, but on Linux the header is left in place.
        // This causes problems when pulling images from Docker Hub on Linux.
        //
        // Docker Hub redirects to AWS S3 via CloudFlare.   Including the Authorization header
        // in the redirected request causes a 400 error to be returned with the XML message:
        //
        //    InvalidRequest: Missing x-amz-content-sha256
        //
        // Removing the Authorization header makes the redirected request work.
        //
        // The spec also requires that if the redirected request is a POST, the method
        // should be changed to GET and the body should be deleted:
        //
        //   https://datatracker.ietf.org/doc/html/rfc7231#section-6.4
        //
        // URLSession makes these changes before calling this delegate method:
        //
        //    https://github.com/swiftlang/swift-corelibs-foundation/blob/265274a4be41b3d4d74fe4626d970898e4df330f/Sources/FoundationNetworking/URLSession/HTTP/HTTPURLProtocol.swift#L567C1-L572C1
        //
        // In the delegate:
        //   - response.url is origin of the redirect response
        //   - request.url is value of the redirect response's Location header
        //
        // URLSession also limits redirect loops:
        //
        //    https://github.com/swiftlang/swift-corelibs-foundation/blob/265274a4be41b3d4d74fe4626d970898e4df330f/Sources/FoundationNetworking/URLSession/HTTP/HTTPURLProtocol.swift#L459C1-L460C38

        var request = request

        guard let origin = response.url, let redirect = request.url else {
            // Reject the redirect if either URL is missing
            completionHandler(nil)
            return
        }

        // https://fetch.spec.whatwg.org/#http-redirect-fetch
        if !origin.hasSameOrigin(as: redirect) {
            // Header names are case-insensitive
            request.allHTTPHeaderFields = request.allHTTPHeaderFields?
                .filter({ $0.key.lowercased() != "authorization" })
        }

        completionHandler(request)
    }
}

extension URL {
    // https://html.spec.whatwg.org/multipage/browsers.html#same-origin
    func hasSameOrigin(as other: URL) -> Bool {
        self.scheme == other.scheme && self.host == other.host && self.port == other.port
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
    func distributionEndpoint(forRepository repository: ImageReference.Repository, andEndpoint endpoint: String) -> URL
    {
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
        var repository: ImageReference.Repository  // Repository path on the registry
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
            _ repository: ImageReference.Repository,
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
            _ repository: ImageReference.Repository,
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
            _ repository: ImageReference.Repository,
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
            _ repository: ImageReference.Repository,
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
            _ repository: ImageReference.Repository,
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
            _ repository: ImageReference.Repository,
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
            // Try to decode as JSON; if that fails, throw a generic error with the raw response body
            do {
                let decoded = try decoder.decode(DistributionErrors.self, from: responseData)
                throw decoded
            } catch is DecodingError {
                let bodyText = String(data: responseData, encoding: .utf8) ?? "<non-UTF8 response>"
                throw RegistryClientError.unexpectedRegistryResponse(status: status.code, body: bodyText)
            }
        }
    }

    /// Execute an HTTP request uploading a request body.
    /// - Parameters:
    ///   - operation: The Registry operation to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    ///   - errors: Expected error codes for which the registry sends structured error messages.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
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
            // Try to decode as JSON; if that fails, throw a generic error with the raw response body
            do {
                let decoded = try decoder.decode(DistributionErrors.self, from: responseData)
                throw decoded
            } catch is DecodingError {
                let bodyText = String(data: responseData, encoding: .utf8) ?? "<non-UTF8 response>"
                throw RegistryClientError.unexpectedRegistryResponse(status: status.code, body: bodyText)
            }
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
