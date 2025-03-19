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

// This file defines a basic tar writer which produces POSIX tar files.
// This avoids the need to depend on a system-provided tar binary.
//
// There are several tar formats, which share the same basic header fields
// but add different extensions.  Writing any particular tar format is
// relatively straightforward;  reading an arbitrary tar file is more
// complicated because the reader must be prepared to handle all variants.

// Tar archives consist of 512-byte blocks, either containing member headers
// or file data.   Blocks shorter than 512 bytes are padded with zeros.
let blockSize = 512

/// Returns the number of padding bytes to be appended to a file.
/// Each file in a tar archive must be padded to a multiple of the 512 byte block size.
/// - Parameter len: The length of the archive member.
/// - Returns: The number of zero bytes to append as padding.
func padding(_ len: Int) -> Int {
    (blockSize - len % blockSize) % blockSize
}

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
    return String(repeating: "0", count: 6 - str.count) + str
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
    return String(repeating: "0", count: 11 - str.count) + str
}

// These ranges define the offsets of the standard fields in a Tar header.
enum Field {
    static let name = 0..<100
    static let mode = 100..<108
    static let uid = 108..<116
    static let gid = 116..<124
    static let size = 124..<136
    static let mtime = 136..<148
    static let chksum = 148..<156
    static let typeflag = 156..<157
    static let linkname = 157..<257
    static let magic = 257..<264
    static let version = 263..<265
    static let uname = 265..<297
    static let gname = 297..<329
    static let devmajor = 329..<337
    static let devminor = 337..<345
    static let prefix = 345..<500
}

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

    precondition(header.count == blockSize)
    return header.reduce(0) { $0 &+ Int($1) }
}

// Tar version fields
let TMAGIC = "ustar"  // POSIX tar
let TVERSION = "00"  // Version used by macOS tar

let INIT_CHECKSUM = "        "  // Initial value of the checksum field before checksum calculation

/// Represents the type of a tar archive member
public enum MemberType: String {
    /// Regular file
    case REGTYPE = "0"

    /// Regular file (alternative)
    case AREGTYPE = "\0"

    /// Link
    case LNKTYPE = "1"

    /// Reserved
    case SYMTYPE = "2"

    /// Character special
    case CHRTYPE = "3"

    /// Block special
    case BLKTYPE = "4"

    /// Directory
    case DIRTYPE = "5"

    /// FIFO special
    case FIFOTYPE = "6"

    /// Reserved
    case CONTTYPE = "7"

    /// Extended header referring to the next file in the archive
    case XHDTYPE = "x"

    /// Global extended header
    case XGLTYPE = "g"
}

// maybe limited string, octal6 and octal11 should be separate types

/// Represents a single tar archive member header
public struct TarHeader {
    /// Member file name when unpacked
    var name: String

    /// Access mode
    var mode: Int = 555

    /// User ID of the file's owner
    var uid: Int = 0

    /// Group ID of the file's owner
    var gid: Int = 0

    /// File size in bytes
    var size: Int = 0

    /// Last modification time
    var mtime: Int = 0

    /// Tar header checksum
    var checksum: String = INIT_CHECKSUM

    /// Type of this member
    var typeflag: MemberType = .REGTYPE

    /// Name of the linked file
    var linkname: String = ""

    /// Tar header magic number
    var magic: String = TMAGIC

    /// Tar header format version
    var version: String = TVERSION

    /// Username of the file's owner
    var uname: String = ""

    /// Group name of the file's owner
    var gname: String = ""

    /// Major device number
    var devmajor: Int = 0

    /// Minor device number
    var devminor: Int = 0

    /// Filename prefix - prepended to name
    var prefix: String = ""

    public init(
        name: String,
        mode: Int = 0o555,
        uid: Int = 0,
        gid: Int = 0,
        size: Int = 0,
        mtime: Int = 0,
        typeflag: MemberType = .REGTYPE,
        linkname: String = "",
        uname: String = "",
        gname: String = "",
        devmajor: Int = 0,
        devminor: Int = 0,
        prefix: String = ""
    ) throws {
        // Archive member name cannot be empty because a Unix filename cannot be the empty string
        //     https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_170
        guard name.count > 0 else {
            throw TarError.invalidName(name)
        }

        self.name = name
        self.mode = mode
        self.uid = uid
        self.gid = gid
        self.size = size
        self.mtime = mtime
        self.checksum = INIT_CHECKSUM
        self.typeflag = typeflag
        self.linkname = linkname
        self.magic = TMAGIC
        self.version = TVERSION
        self.uname = uname
        self.gname = gname
        self.devmajor = devmajor
        self.devminor = devminor
        self.prefix = prefix
    }
}

extension TarHeader {
    /// The serialized byte representation of the header.
    var bytes: [UInt8] {
        // A file entry consists of a file header followed by the
        // contents of the file. The header includes information such as
        // the file name, size and permissions.   Different versions of
        // tar added extra header fields.
        //
        // The file data is padded with nulls to a multiple of 512 bytes.

        var bytes = [UInt8](repeating: 0, count: blockSize)

        // Construct a POSIX ustar header for the file
        bytes.writeString(self.name, inField: Field.name, withTermination: .null)
        bytes.writeString(octal6(self.mode), inField: Field.mode, withTermination: .spaceAndNull)
        bytes.writeString(octal6(self.uid), inField: Field.uid, withTermination: .spaceAndNull)
        bytes.writeString(octal6(self.gid), inField: Field.gid, withTermination: .spaceAndNull)
        bytes.writeString(octal11(self.size), inField: Field.size, withTermination: .space)
        bytes.writeString(octal11(self.mtime), inField: Field.mtime, withTermination: .space)
        bytes.writeString(INIT_CHECKSUM, inField: Field.chksum, withTermination: .none)
        bytes.writeString(self.typeflag.rawValue, inField: Field.typeflag, withTermination: .none)
        bytes.writeString(self.linkname, inField: Field.linkname, withTermination: .null)
        bytes.writeString(TMAGIC, inField: Field.magic, withTermination: .null)
        bytes.writeString(TVERSION, inField: Field.version, withTermination: .none)
        bytes.writeString(self.uname, inField: Field.uname, withTermination: .null)
        bytes.writeString(self.gname, inField: Field.gname, withTermination: .null)
        bytes.writeString(octal6(self.devmajor), inField: Field.devmajor, withTermination: .spaceAndNull)
        bytes.writeString(octal6(self.devminor), inField: Field.devminor, withTermination: .spaceAndNull)
        bytes.writeString(self.prefix, inField: Field.prefix, withTermination: .null)

        // Fill in the checksum.
        bytes.writeString(octal6(Tar.checksum(header: bytes)), inField: Field.chksum, withTermination: .nullAndSpace)

        return bytes
    }
}

/// Creates a tar archive containing a single file
/// - Parameters:
///   - bytes: The file's body data
///   - filename: The file's name in the archive
/// - Returns: A tar archive containing the file
/// - Throws: If the filename is invalid
public func tar(_ bytes: [UInt8], filename: String = "app") throws -> [UInt8] {
    var archive = try TarHeader(name: filename, size: bytes.count).bytes

    // Append the file data to the header
    archive.append(contentsOf: bytes)

    // Pad the file data to a multiple of 512 bytes
    let padding = [UInt8](repeating: 0, count: padding(bytes.count))
    archive.append(contentsOf: padding)

    // Append the end of file marker
    let marker = [UInt8](repeating: 0, count: 2 * blockSize)
    archive.append(contentsOf: marker)
    return archive
}

/// Represents a tar archive
public struct Archive {
    /// The files, directories and other members of the archive
    var members: [ArchiveMember]

    /// Creates an empty Archive
    public init() {
        members = []
    }

    /// Appends a member to the archive
    /// Parameters:
    /// - member: The member to append
    public mutating func append(_ member: ArchiveMember) {
        self.members.append(member)
    }

    /// Returns a new archive made by appending a member to the receiver
    /// Parameters:
    /// - member: The member to append
    /// Returns: A new archive made by appending `member` to the receiver.
    public func appending(_ member: ArchiveMember) -> Self {
        var ret = self
        ret.members += [member]
        return ret
    }

    /// The serialized byte representation of the archive, including padding and end-of-archive marker.
    public var bytes: [UInt8] {
        var ret: [UInt8] = []
        for member in members {
            ret.append(contentsOf: member.bytes)
        }

        // Append the end of file marker
        let marker = [UInt8](repeating: 0, count: 2 * blockSize)
        ret.append(contentsOf: marker)

        return ret
    }
}

/// Represents a member of a tar archive
public struct ArchiveMember {
    /// Member header containing metadata about the member
    var header: TarHeader

    /// File content
    var contents: [UInt8]

    /// Creates a new ArchiveMember
    /// Parameters:
    /// - header: Member header containing metadata about the member
    /// - data: File content
    public init(
        header: TarHeader,
        data: [UInt8] = []
    ) {
        self.header = header
        self.contents = data
    }

    /// The serialized byte representation of the member, including padding.
    public var bytes: [UInt8] {
        let padding = [UInt8](repeating: 0, count: padding(contents.count))
        return header.bytes + self.contents + padding
    }
}

extension Archive {
    /// Adds a new file member at the end of the archive
    /// parameters:
    /// - name: File name
    /// - prefix: Path prefix
    /// - data: File contents
    public mutating func appendFile(name: String, prefix: String = "", data: [UInt8]) throws {
        try append(.init(header: .init(name: name, size: data.count, prefix: prefix), data: data))
    }

    /// Adds a new file member at the end of the archive
    /// parameters:
    /// - name: File name
    /// - prefix: Path prefix
    /// - data: File contents
    public func appendingFile(name: String, prefix: String = "", data: [UInt8]) throws -> Self {
        try appending(.init(header: .init(name: name, size: data.count, prefix: prefix), data: data))
    }

    /// Adds a new directory member at the end of the archive
    /// parameters:
    /// - name: Directory name
    /// - prefix: Path prefix
    public mutating func appendDirectory(name: String, prefix: String = "") throws {
        try append(.init(header: .init(name: name, typeflag: .DIRTYPE, prefix: prefix)))
    }

    /// Adds a new directory member at the end of the archive
    /// parameters:
    /// - name: Directory name
    /// - prefix: Path prefix
    public func appendingDirectory(name: String, prefix: String = "") throws -> Self {
        try self.appending(.init(header: .init(name: name, typeflag: .DIRTYPE, prefix: prefix)))
    }
}
