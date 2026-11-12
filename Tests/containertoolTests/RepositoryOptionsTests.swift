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

import ArgumentParser
import ContainerRegistry
import Testing

@testable import containertool

@Suite struct RepositoryOptionsTests {
    @Test func acceptsUntaggedAndTaggedDestinationImages() throws {
        let untagged = try ContainerTool.parseDestinationImage("example.com/service", defaultRegistry: "docker.io")
        #expect("\(untagged)" == "example.com/service:latest")

        let tagged = try ContainerTool.parseDestinationImage("example.com/service:1.2.3", defaultRegistry: "docker.io")
        #expect("\(tagged)" == "example.com/service:1.2.3")
    }

    @Test(arguments: [
        "example.com/service@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "example.com/service@sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ])
    func rejectsDigestInDestinationImage(reference: String) throws {
        #expect(throws: ValidationError.self) {
            _ = try ContainerTool.parseDestinationImage(reference, defaultRegistry: "docker.io")
        }
    }
}
