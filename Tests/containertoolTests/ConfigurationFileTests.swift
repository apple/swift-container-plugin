//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Testing

@testable import containertool

@Suite struct ConfigurationFileTests {
    @Test func loadFullConfiguration() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent(ContainerToolConfiguration.filename)
            try """
            {
              "defaultRegistry": "ghcr.io",
              "repository": "example/service",
              "tag": "1.2.3",
              "from": "swift:slim",
              "architecture": "arm64",
              "os": "linux",
              "defaultUsername": "user",
              "defaultPassword": "secret"
            }
            """
            .write(to: url, atomically: true, encoding: .utf8)

            let config = try ContainerToolConfiguration.load(from: url)
            #expect(
                config
                    == ContainerToolConfiguration(
                        defaultRegistry: "ghcr.io",
                        repository: "example/service",
                        tag: "1.2.3",
                        from: "swift:slim",
                        architecture: "arm64",
                        os: "linux",
                        defaultUsername: "user",
                        defaultPassword: "secret"
                    )
            )
        }
    }

    @Test func loadPartialConfigurationIgnoresEmptyStrings() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent(ContainerToolConfiguration.filename)
            try """
            {
              "repository": "example/service",
              "from": "",
              "tag": null
            }
            """
            .write(to: url, atomically: true, encoding: .utf8)

            let config = try ContainerToolConfiguration.load(from: url)
            #expect(config.repository == "example/service")
            #expect(config.from == nil)
            #expect(config.tag == nil)
            #expect(config.defaultRegistry == nil)
        }
    }

    @Test func loadReturnsNilWhenFileIsMissing() throws {
        try withTemporaryDirectory { directory in
            let loaded = try ContainerToolConfiguration.load(startingAt: directory)
            #expect(loaded == nil)
        }
    }

    @Test func findConfigurationFileWalksParentDirectories() throws {
        try withTemporaryDirectory { directory in
            let configURL = directory.appendingPathComponent(ContainerToolConfiguration.filename)
            try #"{"repository":"example/from-parent"}"#.write(to: configURL, atomically: true, encoding: .utf8)

            let nested = directory.appendingPathComponent("Sources").appendingPathComponent("App")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

            let loaded = try #require(try ContainerToolConfiguration.load(startingAt: nested))
            #expect(loaded.url.path == configURL.path)
            #expect(loaded.configuration.repository == "example/from-parent")
        }
    }

    @Test func loadThrowsForInvalidJSON() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent(ContainerToolConfiguration.filename)
            try "{ not valid json".write(to: url, atomically: true, encoding: .utf8)

            #expect(throws: ConfigurationFileError.self) {
                _ = try ContainerToolConfiguration.load(from: url)
            }
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("containertool-config-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
