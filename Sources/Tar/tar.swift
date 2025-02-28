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

import struct Foundation.Data

// This file defines a basic tar writer which produces POSIX tar files.
// This avoids the need to depend on a system-provided tar binary.
//
// There are several tar formats, which share the same basic header fields
// but add different extensions.  Writing any particular tar format is
// relatively straightforward;  reading an arbitrary tar file is more
// complicated because the reader must be prepared to handle all variants.

enum TarError: Error, Equatable {
    case invalidName(String)
}

enum Termination {
    case null
    case nullAndSpace
    case space
    case spaceAndNull
    case none
}

extension UInt8 {
    // Some fields use ASCII space characters as part of their termination
    static var asciiSpace: UInt8 { UInt8(ascii: " ") }
}

// with bounds checks in place, can use unchecked arithmetic
extension [UInt8] {
    mutating func writeString(_ string: String, inField field: Range<Int>, withTermination termination: Termination) {
        precondition(string.count <= field.count)
        var i = field.lowerBound
        let bytes = string.utf8
        for b in bytes {
            self[i] = b
            i &+= 1
        }

        switch termination {
        case .null:
            assert((i - field.lowerBound) + 1 <= field.count)
            self[i] = 0x0
        case .nullAndSpace:
            assert((i - field.lowerBound) + 2 <= field.count)
            self[i] = 0x0
            self[i + 1] = .asciiSpace
        case .space:
            assert((i - field.lowerBound) + 1 <= field.count)
            self[i] = .asciiSpace
        case .spaceAndNull:
            assert((i - field.lowerBound) + 2 <= field.count)
            self[i] = .asciiSpace
            self[i + 1] = 0x0
        case .none: break  // no termination
        }
    }
}

/// Serializes an integer to a 6 character octal representation.
/// - Parameter value: The integer to serialize.
/// - Returns: The serialized form of `value`.
func octal6(_ value: Int) -> String {
    precondition(value >= 0)
    precondition(value < 0o777777)
    // String(format: "%06o", value) cannot be used because of a race in Foundation
    // which causes it to return an empty string from time to time when running the tests
    // in parallel using swift-testing: https://github.com/swiftlang/swift-corelibs-foundation/issues/5152
    let str = String(value, radix: 8)
    return String(repeating: "0", count: 6 - str.count).appending(str)
}

/// Serializes an integer to an 11 character octal representation.
/// - Parameter value: The integer to serialize.
/// - Returns: The serialized form of `value`.
func octal11(_ value: Int) -> String {
    precondition(value >= 0)
    precondition(value < 0o777_7777_7777)
    // String(format: "%011o", value) cannot be used because of a race in Foundation
    // which causes it to return an empty string from time to time when running the tests
    // in parallel using swift-testing: https://github.com/swiftlang/swift-corelibs-foundation/issues/5152
    let str = String(value, radix: 8)
    return String(repeating: "0", count: 11 - str.count).appending(str)
}

// These ranges define the offsets of the standard fields in a Tar header.
let name = 0..<100
let mode = 100..<108
let uid = 108..<116
let gid = 116..<124
let size = 124..<136
let mtime = 136..<148
let chksum = 148..<156
let typeflag = 156..<157
let linkname = 157..<257
let magic = 257..<264
let version = 263..<265
let uname = 265..<297
let gname = 297..<329
let devmajor = 329..<337
let devminor = 337..<345
let prefix = 345..<500

/// Calculates a checksum over the contents of a tar header.
/// - Parameter header: Tar header to checksum.
/// - Returns: Checksum value.
func checksum(header: [UInt8]) -> Int {
    // The checksum is the sum of all bytes in the header.
    //   - When calculating the checksum, the checksum field is treated as if it
    //     were filled with spaces (ASCII 32).
    //   - The checksum field is 8 bytes, so if all other bytes are 0x00 the minimum
    //      possible checksum is 8 * 32 == 256.
    //   - If all other bytes are 0xFF the maximum possible checksum is
    //     8 * 32 + (512 - 8) * 255 == 128, 776.
    //
    //  This agrees with the comments in
    //  https://cs.opensource.google/go/go/+/refs/tags/go1.21.0:src/archive/tar/format.go;l=222
    //
    // The checksum calculation can't overflow (maximum possible value 776) so we can use
    // unchecked arithmetic.

    precondition(header.count == 512)
    return header.reduce(0) { $0 &+ Int($1) }
}

// Tar version fields
let TMAGIC = "ustar"  // POSIX tar
let TVERSION = "00"  // Version used by macOS tar

let INIT_CHECKSUM = "        "  // Initial value of the checksum field before checksum calculation

// Typeflag values
let REGTYPE = "0"  // regular file
let AREGTYPE = "\0"  // regular file
let LNKTYPE = "1"  // link
let SYMTYPE = "2"  // reserved
let CHRTYPE = "3"  // character special
let BLKTYPE = "4"  // block special
let DIRTYPE = "5"  // directory
let FIFOTYPE = "6"  // FIFO special
let CONTTYPE = "7"  // reserved
let XHDTYPE = "x"  // Extended header referring to the next file in the archive
let XGLTYPE = "g"  // Global extended header

/// Creates a tar header for a single file
/// - Parameters:
///   - filesize: The size of the file
///   - filename: The file's name in the archive
/// - Returns: A tar header representing the file
/// - Throws: If the filename is invalid
public func tarHeader(filesize: Int, filename: String = "app") throws -> [UInt8] {
    // A file entry consists of a file header followed by the
    // contents of the file. The header includes information such as
    // the file name, size and permissions.   Different versions of
    // tar added extra header fields.
    //
    // The file data is padded with nulls to a multiple of 512 bytes.

    // Archive member name cannot be empty because a Unix filename cannot be the empty string
    // https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_170
    guard filename.count > 0 else {
        throw TarError.invalidName(filename)
    }

    var hdr = [UInt8](repeating: 0, count: 512)

    // Construct a POSIX ustar header for the file
    hdr.writeString(filename, inField: name, withTermination: .null)
    hdr.writeString(octal6(0o555), inField: mode, withTermination: .spaceAndNull)
    hdr.writeString(octal6(0o000000), inField: uid, withTermination: .spaceAndNull)
    hdr.writeString(octal6(0o000000), inField: gid, withTermination: .spaceAndNull)
    hdr.writeString(octal11(filesize), inField: size, withTermination: .space)
    hdr.writeString(octal11(0), inField: mtime, withTermination: .space)
    hdr.writeString(INIT_CHECKSUM, inField: chksum, withTermination: .none)
    hdr.writeString(REGTYPE, inField: typeflag, withTermination: .none)
    hdr.writeString("", inField: linkname, withTermination: .null)
    hdr.writeString(TMAGIC, inField: magic, withTermination: .null)
    hdr.writeString(TVERSION, inField: version, withTermination: .none)
    hdr.writeString("", inField: uname, withTermination: .null)
    hdr.writeString("", inField: gname, withTermination: .null)
    hdr.writeString(octal6(0o000000), inField: devmajor, withTermination: .spaceAndNull)
    hdr.writeString(octal6(0o000000), inField: devminor, withTermination: .spaceAndNull)
    hdr.writeString("", inField: prefix, withTermination: .null)

    // Fill in the checksum.
    hdr.writeString(octal6(checksum(header: hdr)), inField: chksum, withTermination: .nullAndSpace)

    return hdr
}

/// Creates a tar archive containing a single file
/// - Parameters:
///   - bytes: The file's body data
///   - filename: The file's name in the archive
/// - Returns: A tar archive containing the file
/// - Throws: If the filename is invalid
public func tar(_ bytes: [UInt8], filename: String = "app") throws -> [UInt8] {
    var hdr = try tarHeader(filesize: bytes.count, filename: filename)

    // Append the file data to the header
    hdr.append(contentsOf: bytes)

    // Pad the file data to a multiple of 512 bytes
    let padding = [UInt8](repeating: 0, count: 512 - (bytes.count % 512))
    hdr.append(contentsOf: padding)

    // Append the end of file marker
    let marker = [UInt8](repeating: 0, count: 2 * 512)
    hdr.append(contentsOf: marker)
    return hdr
}

/// Creates a tar archive containing a single file
/// - Parameters:
///   - data: The file's body data
///   - filename: The file's name in the archive
/// - Returns: A tar archive containing the file
/// - Throws: If the filename is invalid
public func tar(_ data: Data, filename: String) throws -> [UInt8] {
    try tar([UInt8](data), filename: filename)
}
