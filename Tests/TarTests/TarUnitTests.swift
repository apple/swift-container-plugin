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

    // We should never add a full block (512 bytes) of padding
    @Test(arguments: [
        (input: 0, expected: 0),
        (input: 1, expected: 511),
        (input: 2, expected: 510),
        (input: 511, expected: 1),
        (input: 512, expected: 0),
        (input: 513, expected: 511),
    ])
    func testPadded(input: Int, expected: Int) async throws {
        #expect(padding(input) == expected)
    }

    @Test(arguments: 0...1025)
    func testPaddedProperties(input: Int) async throws {
        let output = padding(input)

        // The padded output should be a whole number of blocks
        #expect((input + output) % 512 == 0)

        // We should never write a full block of padding, because tar considers this to be the end of the file
        #expect(output < 512)
    }

    @Test func testUInt8writeString() async throws {
        // Fill the buffer with 0xFF to show null termination
        var hdr = [UInt8](repeating: 255, count: 21)

        // The typechecker timed out when these test cases were passed as arguments, in the style of the octal tests
        hdr.writeString("abc", inField: 0..<5, withTermination: .none)
        #expect(
            hdr == [
                97, 98, 99, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
            ]
        )

        hdr.writeString("def", inField: 3..<7, withTermination: .null)
        #expect(
            hdr == [97, 98, 99, 100, 101, 102, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
        )

        hdr.writeString("ghi", inField: 7..<11, withTermination: .space)
        #expect(
            hdr == [97, 98, 99, 100, 101, 102, 0, 103, 104, 105, 32, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255]
        )

        hdr.writeString("jkl", inField: 11..<16, withTermination: .nullAndSpace)
        #expect(
            hdr == [97, 98, 99, 100, 101, 102, 0, 103, 104, 105, 32, 106, 107, 108, 0, 32, 255, 255, 255, 255, 255]
        )

        hdr.writeString("mno", inField: 16..<21, withTermination: .spaceAndNull)
        #expect(
            hdr == [97, 98, 99, 100, 101, 102, 0, 103, 104, 105, 32, 106, 107, 108, 0, 32, 109, 110, 111, 32, 0]
        )
    }

    @Test func testEmptyName() async throws {
        #expect(throws: TarError.invalidName("")) {
            let _ = try tarHeader(filesize: 0, filename: "")
        }
    }

    @Test func testSingleEmptyFile() async throws {
        let hdr = try tarHeader(filesize: 0, filename: "filename")
        #expect(hdr.count == 512)
        #expect(
            hdr == [
                102, 105, 108, 101, 110, 97, 109, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                48, 48, 48, 53, 53, 53, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48,
                48, 48, 48, 48, 48, 48, 48, 48, 32, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32, 48, 49, 48, 54, 53,
                55, 0, 32, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                117, 115, 116, 97, 114, 0, 48, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ]
        )
    }

    @Test func testSingle1kBFile() async throws {
        let hdr = try tarHeader(filesize: 1024, filename: "filename")
        #expect(hdr.count == 512)
        #expect(
            hdr == [
                102, 105, 108, 101, 110, 97, 109, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                48, 48, 48, 53, 53, 53, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48,
                48, 48, 48, 48, 50, 48, 48, 48, 32, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32, 48, 49, 48, 54, 54,
                49, 0, 32, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                117, 115, 116, 97, 114, 0, 48, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 32, 0, 48, 48, 48, 48, 48, 48, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ]
        )
    }
}
