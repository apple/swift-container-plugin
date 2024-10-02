//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// Adapted from Sources/Basics/AuthorizationProvider.swift
// Keychain and AuthorizationWriter removed.
// Use of Filesystem and AbsolutePath removed.

import struct Foundation.Data
import struct Foundation.Date
import struct Foundation.URL
#if canImport(Security)
    import Security
#endif

public protocol AuthorizationProvider: Sendable {
    func authentication(for url: URL) -> (user: String, password: String)?
}

public enum AuthorizationProviderError: Error {
    case invalidURLHost
    case notFound
    case cannotEncodePassword
    case other(String)
}

public extension AuthorizationProvider {
    @Sendable
    func httpAuthorizationHeader(for url: URL) -> String? {
        guard let (user, password) = self.authentication(for: url) else {
            return nil
        }
        let authString = "\(user):\(password)"
        guard let authData = authString.data(using: .utf8) else {
            return nil
        }
        return "Basic \(authData.base64EncodedString())"
    }
}

// MARK: - netrc

public final class NetrcAuthorizationProvider: AuthorizationProvider {
    let netrc: Netrc?

    public init(_ path: URL) throws {
        self.netrc = try NetrcAuthorizationProvider.load(path)
    }

    public func authentication(for url: URL) -> (user: String, password: String)? {
        return self.machine(for: url).map { (user: $0.login, password: $0.password) }
    }

    private func machine(for url: URL) -> Basics.Netrc.Machine? {
        // Since updates are appended to the end of the file, we
        // take the _last_ match to use the most recent entry.
        if let machine = NetrcAuthorizationProvider.machine(for: url),
           let existing = self.netrc?.machines.last(where: { $0.name.lowercased() == machine })
        {
            return existing
        }

        // No match found. Use the first default if any.
        if let existing = self.netrc?.machines.first(where: { $0.isDefault }) {
            return existing
        }

        return .none
    }

    private static func load(_ path: URL) throws -> Netrc? {
        do {
            let content = try? String(contentsOf: path, encoding: .utf8)
            return try NetrcParser.parse(content ?? "")
        } catch NetrcError.machineNotFound {
            // Thrown by parse() if .netrc is empty.
            // SwiftPM suppresses this error, so we will follow suit.
            return .none
        }
    }

    private static func machine(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else {
            return nil
        }
        return host.isEmpty ? nil : host
    }
}
