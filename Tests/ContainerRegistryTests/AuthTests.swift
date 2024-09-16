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
import Basics
import XCTest

class AuthTests: XCTestCase {
    // SwiftPM's NetrcAuthorizationProvider does not throw an error if the .netrc file
    // does not exist.   For simplicity the local vendored version does the same.
    func testNonexistentNetrc() async throws {
        // Construct a URL to a nonexistent file in the bundle directory
        let netrcURL = Bundle.module.resourceURL!.appendingPathComponent("netrc.nonexistent")
        XCTAssertFalse(FileManager.default.fileExists(atPath: netrcURL.path))

        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        XCTAssertNil(authProvider.authentication(for: URL(string: "https://hub.example.com")!))
    }

    func testEmptyNetrc() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "empty")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        XCTAssertNil(authProvider.authentication(for: URL(string: "https://hub.example.com")!))
    }

    func testBasicNetrc() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "basic")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)
        XCTAssertNil(authProvider.authentication(for: URL(string: "https://nothing.example.com")!))

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://hub.example.com")!) else {
            return XCTFail("Expected to find a username and password")
        }
        XCTAssertEqual(user, "swift")
        XCTAssertEqual(password, "password")
    }

    // The default entry is used if no specific entry matches
    func testComplexNetrcWithDefault() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://nothing.example.com")!)
        else { return XCTFail("Expected to find a username and password") }
        XCTAssertEqual(user, "defaultlogin")
        XCTAssertEqual(password, "defaultpassword")
    }

    // The default entry must be last in the file
    func testComplexNetrcWithInvalidDefault() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "invaliddefault")!
        XCTAssertThrowsError(try NetrcAuthorizationProvider(netrcURL)) { error in
            XCTAssertEqual(error as! NetrcError, NetrcError.invalidDefaultMachinePosition)
        }
    }

    // If there are multiple entries for the same host, the last one wins
    func testComplexNetrcOverriddenEntry() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://hub.example.com")!) else {
            return XCTFail("Expected to find a username and password")
        }
        XCTAssertEqual(user, "swift2")
        XCTAssertEqual(password, "password2")
    }

    // A singleton entry in a netrc file with defaults and overriden entries continues to work as in the simple case
    func testComplexNetrcSingletonEntry() async throws {
        let netrcURL = Bundle.module.url(forResource: "netrc", withExtension: "default")!
        let authProvider = try NetrcAuthorizationProvider(netrcURL)

        guard let (user, password) = authProvider.authentication(for: URL(string: "https://another.example.com")!)
        else { return XCTFail("Expected to find a username and password") }
        XCTAssertEqual(user, "anotherlogin")
        XCTAssertEqual(password, "anotherpassword")
    }
}
