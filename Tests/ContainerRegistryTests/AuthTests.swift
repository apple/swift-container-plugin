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
import Testing

struct AuthTests {
    // SwiftPM's NetrcAuthorizationProvider does not throw an error if the .netrc file
    // does not exist.   For simplicity the local vendored version does the same.
    @Test func testNonexistentNetrc() async throws {
        // Construct a URL to a nonexistent file in the bundle directory
        let netrcURL = Bundle.module.resourceURL!.appendingPathComponent("netrc.nonexistent")
        #expect(!FileManager.default.fileExists(atPath: netrcURL.path))

        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        #expect(authProvider.authentication(for: URL(string: "https://hub.example.com")!) == nil)
    }

    @Test func testEmptyNetrc() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "empty")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        #expect(authProvider.authentication(for: URL(string: "https://hub.example.com")!) == nil)
    }

    @Test func testBasicNetrc() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "basic")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        #expect(authProvider.authentication(for: URL(string: "https://nothing.example.com")!) == nil)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://hub.example.com")!) else {
            Issue.record("Expected to find a username and password")
            return
        }
        #expect(user == "swift")
        #expect(password == "password")
    }

    // The default entry is used if no specific entry matches
    @Test func testComplexNetrcWithDefault() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://nothing.example.com")!)
        else {
            Issue.record("Expected to find a username and password")
            return
        }
        #expect(user == "defaultlogin")
        #expect(password == "defaultpassword")
    }

    // The default entry must be last in the file
    @Test func testComplexNetrcWithInvalidDefault() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "invaliddefault")!
        #expect { try NetrcAuthorizationProvider(netrcURL) } throws: { error in
            error as! NetrcError == NetrcError.invalidDefaultMachinePosition
        }
    }

    // If there are multiple entries for the same host, the last one wins
    @Test func testComplexNetrcOverriddenEntry() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://hub.example.com")!) else {
            Issue.record("Expected to find a username and password")
            return
        }
        #expect(user == "swift2")
        #expect(password == "password2")
    }

    // A singleton entry in a netrc file with defaults and overriden entries continues to work as in the simple case
    @Test func testComplexNetrcSingletonEntry() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://another.example.com")!)
        else {
            Issue.record("Expected to find a username and password")
            return
        }
        #expect(user == "anotherlogin")
        #expect(password == "anotherpassword")
    }
}
