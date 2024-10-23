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
import HTTPTypesFoundation

// HEAD does not include a response body so if an error is thrown, data will be nil
public enum HTTPClientError: Error {
    case unexpectedStatusCode(status: HTTPResponse.Status, response: HTTPResponse, data: Data?)
    case unexpectedContentType(String)
    case missingContentType
    case missingResponseHeader(String)
    case authenticationChallenge(challenge: String, request: HTTPRequest, response: HTTPResponse)
    case unauthorized(request: HTTPRequest, response: HTTPResponse)
}

/// HTTPClient is an abstract HTTP client interface capable of uploads and downloads.
public protocol HTTPClient {
    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - expectingStatus: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func executeRequestThrowing(_ request: HTTPRequest, expectingStatus: HTTPResponse.Status) async throws -> (
        Data, HTTPResponse
    )

    /// Execute an HTTP request uploading a request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - uploading: The request body to upload.
    ///   - expectingStatus: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func executeRequestThrowing(_ request: HTTPRequest, uploading: Data, expectingStatus: HTTPResponse.Status)
        async throws -> (Data, HTTPResponse)
}

extension URLSession: HTTPClient {
    /// Check that a registry response has the correct status code and does not report an error.
    /// - Parameters:
    ///   - request: The request made to the registry.
    ///   - response: The response from the registry.
    ///   - responseData: The raw response body data returned by the registry.
    ///   - successfulStatus: The successful HTTP response expected from this request.
    /// - Returns: An HTTPResponse representing the response, if the response was valid.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    func validateAPIResponseThrowing(
        request: HTTPRequest,
        response: HTTPResponse,
        responseData: Data,
        expectingStatus successfulStatus: HTTPResponse.Status
    ) throws -> HTTPResponse {
        // Convert errors into exceptions
        guard response.status == successfulStatus else {
            // If the response includes an authentication challenge the client can try again,
            // presenting the challenge response.
            if response.status == .unauthorized {
                if let authChallenge = response.headerFields[.wwwAuthenticate] {
                    throw HTTPClientError.authenticationChallenge(
                        challenge: authChallenge.trimmingCharacters(in: .whitespacesAndNewlines),
                        request: request,
                        response: response
                    )
                }
            }

            // A HEAD request has no response body and cannot be decoded
            if request.method == .head {
                throw HTTPClientError.unexpectedStatusCode(status: response.status, response: response, data: nil)
            }
            throw HTTPClientError.unexpectedStatusCode(status: response.status, response: response, data: responseData)
        }

        return response
    }

    /// Execute an HTTP request with no request body.
    /// - Parameters:
    ///   - request: The HTTP request to execute.
    ///   - success: The HTTP status code expected if the request is successful.
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing(_ request: HTTPRequest, expectingStatus success: HTTPResponse.Status)
        async throws -> (Data, HTTPResponse)
    {
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
    /// - Returns: An asynchronously-delivered tuple that contains the raw response body as a Data instance, and a HTTPResponse.
    /// - Throws: If the server response is unexpected or indicates that an error occurred.
    public func executeRequestThrowing(
        _ request: HTTPRequest,
        uploading payload: Data,
        expectingStatus success: HTTPResponse.Status
    ) async throws -> (Data, HTTPResponse) {
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

extension HTTPRequest {
    /// Constructs a HTTPRequest pre-configured with method, url and content types.
    /// - Parameters:
    ///   - method: HTTP method to use: "GET", "PUT" etc
    ///   - url: The URL on which to operate.
    ///   - accepting: A list of acceptable content-types.
    ///   - contentType: The content-type of the request's body data, if any.
    ///   - authorization: Authorization credentials for this request.
    init(
        method: HTTPRequest.Method,
        url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) {
        self.init(url: url)
        self.method = method
        if let contentType { headerFields[.contentType] = contentType }
        if accepting.count > 0 { headerFields[values: .accept] = accepting }

        // The URLSession documentation warns not to do this:
        //    https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411532-httpadditionalheaders#discussion
        // However this is the best option when URLSession does not support the server's authentication scheme:
        //    https://developer.apple.com/forums/thread/89811
        if let authorization { headerFields[.authorization] = authorization }
    }

    static func get(
        _ url: URL,
        accepting: [String] = [],
        contentType: String? = nil,
        withAuthorization authorization: String? = nil
    ) -> HTTPRequest {
        .init(method: .get, url: url, accepting: accepting, contentType: contentType, withAuthorization: authorization)
    }
}
