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

import Basics
import Foundation
import RegexBuilder
import HTTPTypes

struct BearerTokenResponse: Codable {
    /// An opaque Bearer token that clients should supply to
    /// subsequent requests in the Authorization header.
    var token: String

    /// For compatibility with OAuth 2.0, the registry considers
    /// access_token to be a synonym for token.
    var access_token: String?

    /// Number of seconds the token will remain valid.
    var expires_in: Int?

    /// The RFC3339-serialized UTC standard time at which a
    /// given token was issued. If issued_at is omitted, the
    /// expiration is from when the token exchange completed.
    var issued_at: String?

    /// Token which can be used to get additional access tokens
    /// for the same subject with different scopes.
    var refresh_token: String?
}

struct BearerChallenge {
    var realm: String? = nil
    var scope: [String] = []
    var service: String? = nil
    var other: [(String, String)] = []  // unrecognized fields in the challenge

    /// A URL created from the challenge components.
    var url: URL? {
        var components = URLComponents()
        guard let realm else { return nil }

        if let service {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "service", value: service)]
        }

        for s in scope {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "scope", value: s)]
        }

        return components.url(relativeTo: .init(string: realm))
    }
}

enum ChallengeParserError: Error {
    case prefixMatchFailed(String)
    case leftoverCharacters(String)
}

func parseChallenge(_ s: String) throws -> BearerChallenge {
    let nonQuote = try Regex(#"[^"]"#)
    let kv = Regex {
        Capture { OneOrMore { .word } }
        "="
        "\""
        Capture { OneOrMore { nonQuote } }
        "\""
    }
    let commaKV = Regex {
        ","
        kv
    }

    var res = BearerChallenge()

    var s = Substring(s)

    guard let match = s.prefixMatch(of: kv) else { throw ChallengeParserError.prefixMatchFailed(String(s)) }

    switch match.1 {
    case "realm": res.realm = String(match.2)
    case "service": res.service = String(match.2)
    case "scope": res.scope.append(String(match.2))
    default: res.other.append((String(match.1), String(match.2)))
    }
    s.trimPrefix(match.0)

    while let match = s.prefixMatch(of: commaKV) {
        switch match.1 {
        case "realm": res.realm = String(match.2)
        case "service": res.service = String(match.2)
        case "scope": res.scope.append(String(match.2))
        default: res.other.append((String(match.1), String(match.2)))
        }
        s.trimPrefix(match.0)
    }

    if s != "" { throw ChallengeParserError.leftoverCharacters(String(s)) }

    return res
}

public enum AuthChallenge: Equatable {
    case none
    case basic(String)
    case bearer(String)

    init(challenge: String) {
        if challenge.lowercased().starts(with: "basic") {
            self = .basic(challenge)
        } else if challenge.lowercased().starts(with: "bearer") {
            self = .bearer(challenge)
        } else {
            self = .none
        }
    }
}

/// AuthHandler manages provides credentials for HTTP requests
public struct AuthHandler {
    var username: String?
    var password: String?

    var auth: AuthorizationProvider? = nil
    /// Create an AuthHandler
    /// - Parameters:
    ///   - username: Default username, used if no other suitable credentials are available.
    ///   - password: Default password, used if no other suitable credentials are available.
    ///   - auth: AuthorizationProvider capable of querying credential stores such as netrc files.
    public init(username: String? = nil, password: String? = nil, auth: AuthorizationProvider? = nil) {
        self.username = username
        self.password = password
        self.auth = auth
    }

    /// Get locally-configured credentials, such as netrc or username/password, for a host
    func localCredentials(forURL url: URL) -> String? {
        if let netrcEntry = auth?.httpAuthorizationHeader(for: url) { return netrcEntry }

        if let username, let password {
            let authorization = Data("\(username):\(password)".utf8).base64EncodedString()
            return "Basic \(authorization)"
        }

        // No suitable authentication methods available
        return nil
    }

    public func auth(
        registry: URL,
        repository: String,
        actions: [String],
        withScheme scheme: AuthChallenge,
        usingClient client: HTTPClient
    ) async throws -> String? {
        switch scheme {
        case .none: return nil
        case .basic: return localCredentials(forURL: registry)

        case .bearer(let challenge):
            // Preemptively offer suitable basic auth credentials to the token server.
            // Instead of challenging, public token servers often return anonymous tokens when no credentials are offered.
            // These tokens allow pull access to public repositories, but attempts to push will fail with 'unauthorized'.
            // There is no obvious prompt for the client to retry with authentication.
            var parsedChallenge = try parseChallenge(
                challenge.dropFirst("bearer".count).trimmingCharacters(in: .whitespacesAndNewlines)
            )
            parsedChallenge.scope = ["repository:\(repository):\(actions.joined(separator: ","))"]
            guard let challengeURL = parsedChallenge.url else { return nil }
            var tokenRequest = HTTPRequest(url: challengeURL)
            if let credentials = localCredentials(forURL: challengeURL) {
                tokenRequest.headerFields[.authorization] = credentials
            }

            let (data, _) = try await client.executeRequestThrowing(tokenRequest, expectingStatus: .ok)
            let tokenResponse = try JSONDecoder().decode(BearerTokenResponse.self, from: data)
            return "Bearer \(tokenResponse.token)"
        }
    }
}
