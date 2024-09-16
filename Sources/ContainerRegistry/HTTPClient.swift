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

// HEAD does not include a response body so if an error is thrown, data will be nil
public enum HTTPClientError: Error {
    case nonHTTPResponse(URLResponse)
    case unexpectedStatusCode(status: Int, response: HTTPURLResponse, data: Data?)
    case unexpectedContentType(String)
    case missingContentType
    case missingResponseHeader(String)
    case authenticationChallenge(challenge: String, request: URLRequest, response: HTTPURLResponse)
    case unauthorized(request: URLRequest, response: HTTPURLResponse)
}

/// HTTPClient is an abstract HTTP client interface capable of uploads and downloads.
public protocol HTTPClient {
    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - expectingStatus: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func executeRequestThrowing(_ request: URLRequest, expectingStatus: Int) async throws -> (Data, HTTPURLResponse)

    /// Execute an HTTP request uploading a request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - uploading: The request body to upload.
    ///   - expectingStatus: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func executeRequestThrowing(_ request: URLRequest, uploading: Data, expectingStatus: Int) async throws -> (
        Data, HTTPURLResponse
    )
}

extension URLSession: HTTPClient {
    /// Check that a registry response has the correct status code and does not report an error.
    /// - Parameters:
    ///   - request: The request made to the registry.
    ///   - response: The response from the registry.
    ///   - responseData: The raw response body data returned by the registry.
    ///   - successfulStatus: The successful HTTP response expected from this request.
    /// - Returns: An HTTPURLResponse representing the response, if the response was valid.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func validateAPIResponseThrowing(
        request: URLRequest,
        response: URLResponse,
        responseData: Data,
        expectingStatus successfulStatus: Int
    ) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else { throw HTTPClientError.nonHTTPResponse(response) }

        // Convert errors into exceptions
        guard httpResponse.statusCode == successfulStatus else {
            // If the response includes an authentication challenge the client can try again
            if httpResponse.statusCode == 401 {
                if let authChallenge = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") {
                    throw HTTPClientError.authenticationChallenge(
                        challenge: authChallenge.trimmingCharacters(in: .whitespacesAndNewlines),
                        request: request,
                        response: httpResponse
                    )
                }
            }

            // Content-Type should always be set, but there may be registries which don't set it.   If it is not present, the HTTP standard allows
            // clients to guess the content type, or default to `application/octet-stream'.
            guard let _ = httpResponse.value(forHTTPHeaderField: "Content-Type") else {
                throw HTTPClientError.missingResponseHeader("Content-Type")
            }

            // A HEAD request has no response body and cannot be decoded
            if request.httpMethod == "HEAD" {
                throw HTTPClientError.unexpectedStatusCode(
                    status: httpResponse.statusCode,
                    response: httpResponse,
                    data: nil
                )
            }
            throw HTTPClientError.unexpectedStatusCode(
                status: httpResponse.statusCode,
                response: httpResponse,
                data: responseData
            )
        }

        return httpResponse
    }

    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - success: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing(_ request: URLRequest, expectingStatus success: Int) async throws -> (
        Data, HTTPURLResponse
    ) {
        let (responseData, urlResponse) = try await data(for: request)
        let httpResponse = try validateAPIResponseThrowing(
            request: request,
            response: urlResponse,
            responseData: responseData,
            expectingStatus: success
        )
        return (responseData, httpResponse)
    }

    /// Execute an HTTP request uploading a request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - payload: The request body to upload.
    ///   - success: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPURLResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing(_ request: URLRequest, uploading payload: Data, expectingStatus success: Int)
        async throws -> (Data, HTTPURLResponse)
    {
        let (responseData, urlResponse) = try await upload(for: request, from: payload)
        let httpResponse = try validateAPIResponseThrowing(
            request: request,
            response: urlResponse,
            responseData: responseData,
            expectingStatus: success
        )
        return (responseData, httpResponse)
    }
}

extension URLRequest {
    /// Constructs a URLRequest pre-configured with method, url and content types.
    /// - Parameters:
    ///   - method: HTTP method to use: "GET", "PUT" etc
    ///   - url: The URL on which to operate.
    ///   - accepting: A list of acceptable content-types.
    ///   - contentType: The content-type of the request's body data, if any.
    ///   - authorization: Authorization credentials for this request.
    init(
        method: String,
        url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) {
        self.init(url: url)
        httpMethod = method
        if let contentType { addValue(contentType, forHTTPHeaderField: "Content-Type") }
        for acceptContentType in accepting { addValue(acceptContentType, forHTTPHeaderField: "Accept") }

        // The URLSession documentation warns not to do this:
        //    https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411532-httpadditionalheaders#discussion
        // However this is the best option when URLSession does not support the server's authentication scheme:
        //    https://developer.apple.com/forums/thread/89811
        if let authorization { addValue(authorization, forHTTPHeaderField: "Authorization") }
    }

    static func get(
        _ url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) -> URLRequest {
        .init(method: "GET", url: url, accepting: accepting, contentType: contentType, withAuthorization: authorization)
    }

    static func head(
        _ url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) -> URLRequest {
        .init(
            method: "HEAD",
            url: url,
            accepting: accepting,
            contentType: contentType,
            withAuthorization: authorization
        )
    }

    static func put(
        _ url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) -> URLRequest {
        .init(method: "PUT", url: url, accepting: accepting, contentType: contentType, withAuthorization: authorization)
    }

    static func post(
        _ url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) -> URLRequest {
        .init(
            method: "POST",
            url: url,
            accepting: accepting,
            contentType: contentType,
            withAuthorization: authorization
        )
    }
}
