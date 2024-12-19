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
import Testing

@testable import Tar

let blocksize = 512
let headerLen = blocksize
let trailerLen = 2 * blocksize

@Suite struct TarUnitTests {
    @Test(arguments: [
        (input: 0o000, expected: "000000"),
        (input: 0o555, expected: "000555"),
        (input: 0o750, expected: "000750"),
        (input: 0o777, expected: "000777"),
        (input: 0o1777, expected: "001777"),
    ])
    func testOctal6(input: Int, expected: String) async throws {
        #expect(octal6(input) == expected)
    }

    @Test(arguments: [
        (input: 0, expected: "00000000000"),
        (input: 1024, expected: "00000002000"),
        (input: 0o2000, expected: "00000002000"),
        (input: 1024 * 1024, expected: "00004000000"),
    ])
    func testOctal11(input: Int, expected: String) async throws {
        #expect(octal11(input) == expected)
    }
}
