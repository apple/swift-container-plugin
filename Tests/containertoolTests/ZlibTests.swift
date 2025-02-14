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

@testable import containertool
import struct Crypto.SHA256
import Testing

// Check that compressing the same data on macOS and Linux produces the same output.
struct ZlibTests {
    @Test func testGzipHeader() async throws {
        let data = "test"
        let result = gzip([UInt8](data.utf8))
        #expect(
            "\(SHA256.hash(data: result))"
                == "SHA256 digest: 7dff8d09129482017247cb373e8138772e852a1a02f097d1440387055d2be69c"
        )
    }
}
