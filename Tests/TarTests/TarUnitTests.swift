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

let blockSize = 512
let headerSize = blockSize
let trailerSize = 2 * blockSize

let trailer = [UInt8](repeating: 0, count: trailerSize)

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
            let _ = try TarHeader(name: "", size: 0)
        }
    }

    @Test func testSingleEmptyFile() async throws {
        let hdr = try TarHeader(name: "filename", size: 0).bytes
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
        let hdr = try TarHeader(name: "filename", size: 1024).bytes
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

    let emptyFile: [UInt8] = [
        // name: 100 bytes
        101, 109, 112, 116, 121, 102, 105, 108, 101, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,

        // mode: 8 bytes
        48, 48, 48, 53, 53, 53, 32, 0,

        // uid: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // gid: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // size: 12 bytes
        48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32,

        // mtime: 12 bytes
        48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32,

        // chksum: 8 bytes
        48, 49, 49, 48, 55, 53, 0, 32,

        // typeflag: 1 byte
        48,

        // linkname: 100 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,

        // magic: 6 bytes
        117, 115, 116, 97, 114, 0,

        // version: 2 bytes
        48, 48,

        // uname: 32 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // gname: 32 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // devmajor: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,
        // devminor: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // prefix: 155 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // padding: 12 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]

    @Test func testAppendingEmptyFile() async throws {
        let archive = try Archive().appendingFile(name: "emptyfile", data: []).bytes

        // Expecting: member header, no file content, 2-block end of archive marker
        #expect(archive.count == headerSize + trailerSize)
        #expect(archive == emptyFile + trailer)
    }

    let helloFile: [UInt8] =
        [
            // name: 100 bytes
            104, 101, 108, 108, 111, 102, 105, 108, 101, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0,

            // mode: 8 bytes
            48, 48, 48, 53, 53, 53, 32, 0,

            // uid: 8 bytes
            48, 48, 48, 48, 48, 48, 32, 0,

            // gid: 8 bytes
            48, 48, 48, 48, 48, 48, 32, 0,

            // size: 12 bytes
            48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 53, 32,

            // mtime: 12 bytes
            48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32,

            // chksum: 8 bytes
            48, 49, 49, 48, 52, 55, 0, 32,

            // typeflag: 1 byte
            48,

            // linkname: 100 bytes
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0,

            // magic: 6 bytes
            117, 115, 116, 97, 114, 0,

            // version: 2 bytes
            48, 48,

            // uname: 32 bytes
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

            // gname: 32 bytes
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

            // devmajor: 8 bytes
            48, 48, 48, 48, 48, 48, 32, 0,
            // devminor: 8 bytes
            48, 48, 48, 48, 48, 48, 32, 0,

            // prefix: 155 bytes
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

            // padding: 12 bytes
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ] + [
            // file contents: "hello", padded to 512 bytes
            104, 101, 108, 108, 111, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]

    @Test func testAppendFile() async throws {
        var archive = Archive()
        try archive.appendFile(name: "hellofile", data: [UInt8]("hello".utf8))
        let output = archive.bytes

        // Expecting: member header, file content, 2-block end of archive marker
        #expect(output.count == headerSize + blockSize + trailerSize)
        #expect(output == helloFile + trailer)
    }

    @Test func testAppendingFile() async throws {
        let archive = try Archive().appendingFile(name: "hellofile", data: [UInt8]("hello".utf8)).bytes

        // Expecting: member header, file content, 2-block end of archive marker
        #expect(archive.count == headerSize + blockSize + trailerSize)
        #expect(archive == helloFile + trailer)
    }

    let directoryWithPrefix: [UInt8] = [
        // name: 100 bytes
        100, 105, 114, 101, 99, 116, 111, 114, 121, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,

        // mode: 8 bytes
        48, 48, 48, 53, 53, 53, 32, 0,

        // uid: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // gid: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // size: 12 bytes
        48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32,

        // mtime: 12 bytes
        48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 32,

        // chksum: 8 bytes
        48, 49, 50, 51, 50, 54, 0, 32,

        // typeflag: 1 byte
        53,

        // linkname: 100 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,

        // magic: 6 bytes
        117, 115, 116, 97, 114, 0,

        // version: 2 bytes
        48, 48,

        // uname: 32 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // gname: 32 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // devmajor: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,
        // devminor: 8 bytes
        48, 48, 48, 48, 48, 48, 32, 0,

        // prefix: 155 bytes
        112, 114, 101, 102, 105, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        // padding: 12 bytes
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]

    @Test func testAppendDirectory() async throws {
        var archive = Archive()
        try archive.appendDirectory(name: "directory", prefix: "prefix")
        let output = archive.bytes

        // Expecting: member header, no content, 2-block end of archive marker
        #expect(output.count == headerSize + trailerSize)
        #expect(output == directoryWithPrefix + trailer)
    }

    @Test func testAppendingDirectory() async throws {
        let archive = try Archive().appendingDirectory(name: "directory", prefix: "prefix").bytes

        // Expecting: member header, no content, 2-block end of archive marker
        #expect(archive.count == headerSize + trailerSize)
        #expect(archive == directoryWithPrefix + trailer)
    }

    @Test func testAppendFilesAndDirectories() async throws {
        var archive = Archive()
        try archive.appendFile(name: "hellofile", data: [UInt8]("hello".utf8))
        try archive.appendFile(name: "emptyfile", data: [UInt8]())
        try archive.appendDirectory(name: "directory", prefix: "prefix")

        let output = archive.bytes

        // Expecting: file member header, file content, file member header, no file content,
        //     directory member header, 2-block end of archive marker
        #expect(output.count == headerSize + blockSize + headerSize + headerSize + trailerSize)
        #expect(output == helloFile + emptyFile + directoryWithPrefix + trailer)
    }

    @Test func testAppendingFilesAndDirectories() async throws {
        let archive = try Archive()
            .appendingFile(name: "hellofile", data: [UInt8]("hello".utf8))
            .appendingFile(name: "emptyfile", data: [UInt8]())
            .appendingDirectory(name: "directory", prefix: "prefix")
            .bytes

        // Expecting: file member header, file content, file member header, no file content,
        //     directory member header, 2-block end of archive marker
        #expect(archive.count == headerSize + blockSize + headerSize + headerSize + trailerSize)
        #expect(archive == helloFile + emptyFile + directoryWithPrefix + trailer)
    }
}
