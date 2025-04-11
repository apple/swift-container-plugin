//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import class Foundation.FileHandle
import struct Foundation.URL

struct ArrayField<T: Collection> where T.Element == UInt8 {
    var start: Int
    var count: Int
}

struct IntField<T: BinaryInteger> {
    var start: Int
}

extension Array where Element == UInt8 {
    subscript(idx: ArrayField<[UInt8]>) -> [UInt8] {
        [UInt8](self[idx.start..<idx.start + idx.count])
    }

    subscript(idx: IntField<UInt8>) -> UInt8 {
        self[idx.start]
    }

    subscript(idx: IntField<UInt16>, endianness endianness: ELF.Endianness) -> UInt16 {
        let (a, b) = (UInt16(self[idx.start]), UInt16(self[idx.start + 1]))

        switch endianness {
        case .littleEndian:
            return a &<< 0 &+ b &<< 8
        case .bigEndian:
            return a &<< 8 &+ b &<< 0
        }
    }
}

/// ELF header
///
/// - https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
/// - https://refspecs.linuxbase.org/elf/elf.pdf
///
/// This struct only defines enough fields to identify a valid ELF file
/// and extract the type of object it contains, and the processor
/// architecture and operating system ABI for which that object
/// was created.
struct ELF: Equatable {
    /// Minimum ELF header length is 52 bytes for a 32-bit ELF header.
    /// A 64-bit header is 64 bytes.   A potential header must be at
    /// least 52 bytes or it cannot possibly be an ELF header.
    static let minHeaderLength = 52

    /// Multibyte ELF fields are stored in the native endianness of the target system.
    /// This field records the endianness of objects in the file.
    enum Endianness: UInt8 {
        case littleEndian = 0x01
        case bigEndian = 0x02
    }

    /// Offsets (addresses) are stored as 32-bit or 64-bit integers.
    /// This field records the offset size used in objects in the file.
    /// Variable offset sizes mean that some fields are found at different
    /// offsets in 32-bit and 64-bit ELF files.
    enum Encoding: UInt8 {
        case bits32 = 0x01
        case bits64 = 0x02
    }

    /// ELF files can hold a variety of different object types.
    /// This field records type of object in the file.
    /// The standard defines a number of fixed types but also
    /// reserves ranges of type numbers for to be used by
    /// specific operating systems and processors.
    enum Object: Equatable {
        case none
        case relocatable
        case executable
        case shared
        case core
        case reservedOS(UInt16)
        case reservedCPU(UInt16)
        case unknown(UInt16)

        init?(rawValue: UInt16) {
            switch rawValue {
            case 0x0000: self = .none
            case 0x0001: self = .relocatable
            case 0x0002: self = .executable
            case 0x0003: self = .shared
            case 0x0004: self = .core

            /// Reserved for OS-specific use
            case 0xfe00...0xfeff: self = .reservedOS(rawValue)

            /// Reserved for CPU-specific use
            case 0xff00...0xffff: self = .reservedCPU(rawValue)

            default: return nil
            }
        }
    }

    /// The ABI used by the object in this ELF file. The standard reserves values for a variety of ABIs and operating systems;  only a few are implemented here.
    enum ABI: Equatable {
        case SysV
        case Linux
        case unknown(UInt8)

        init(rawValue: UInt8) {
            switch rawValue {
            case 0x00: self = .SysV
            case 0x03: self = .Linux
            default: self = .unknown(rawValue)
            }
        }
    }

    /// The processor architecture used by the object in this ELF file. Values are reserved for many ISAs;
    /// this enum includes cases for the linux-* host types for which Swift can currently be built:
    ///
    /// https://github.com/swiftlang/swift/blob/c6d1060778f35631000911372d7645dbd5cade0a/utils/build-script-impl#L458
    enum ISA: Equatable {
        case x86
        case powerpc
        case powerpc64
        case s390  // incluing s390x
        case arm  // up to armv7
        case x86_64
        case aarch64  // armv8 onwards
        case riscv
        case unknown(UInt16)

        init(rawValue: UInt16) {
            switch rawValue {
            case 0x0003: self = .x86
            case 0x0014: self = .powerpc
            case 0x0015: self = .powerpc64
            case 0x0016: self = .s390
            case 0x0028: self = .arm
            case 0x003e: self = .x86_64
            case 0x00b7: self = .aarch64
            case 0x00f3: self = .riscv
            default: self = .unknown(rawValue)
            }
        }
    }

    var encoding: Encoding
    var endianness: Endianness
    var ABI: ABI
    var object: Object
    var ISA: ISA
}

extension ELF {
    /// ELF header field addresses
    ///
    /// The ELF format can store binaries for 32-bit and 64-bit systems,
    /// using little-endian and big-endian data encoding.
    ///
    /// All multibyte fields are stored using the endianness of the target
    /// system.  Read the EI_DATA field to find the endianness of the file.
    ///
    /// Some fields are different sizes in 32-bit and 64-bit ELF files, but
    /// these occur after all the fields we need to read for basic file type
    /// identification, so all our offsets are the same on 32-bit and 64-bit systems.
    enum Field {
        /// ELF magic number: a string of 4 bytes, not a UInt32; no endianness
        static let EI_MAGIC = ArrayField<[UInt8]>(start: 0x0, count: 4)

        /// ELF class (word size): 1 byte
        static let EI_CLASS = IntField<UInt8>(start: 0x4)

        /// Data encoding (endianness): 1 byte
        static let EI_DATA = IntField<UInt8>(start: 0x5)

        // ELF version: 1 byte
        static let EI_VERSION = IntField<UInt8>(start: 0x6)

        // Operating system/ABI identification: 1 byte
        static let EI_OSABI = IntField<UInt8>(start: 0x7)

        // The following fields are multibyte, so endianness must be considered,
        // All the fields we need are the same length in 32-bit and 64-bit
        // ELF files, so their offsets do not change.

        /// Object type: 2 bytes
        static let EI_TYPE = IntField<UInt16>(start: 0x10)

        /// Machine ISA (processor architecture): 2 bytes
        static let EI_MACHINE = IntField<UInt16>(start: 0x12)
    }

    /// The initial magic number (4 bytes) which identifies an ELF file.
    ///
    /// The ELF magic number is *not* a multibyte integer.  It is defined as a
    /// string of 4 individual bytes and is the same for little-endian and
    /// big-endian ELF files.
    static let ELFMagic = Array("\u{7f}ELF".utf8)

    /// Read enough of an ELF header from bytes to discover the object type,
    /// processor architecture and operating system ABI.
    static func read(_ bytes: [UInt8]) -> ELF? {
        // An ELF file starts with a magic number which is the same in either endianness.
        // The only defined ELF header version is 1.
        guard bytes.count >= minHeaderLength, bytes[Field.EI_MAGIC] == ELFMagic, bytes[Field.EI_VERSION] == 1 else {
            return nil
        }

        guard
            let encoding = Encoding(rawValue: bytes[Field.EI_CLASS]),
            let endianness = Endianness(rawValue: bytes[Field.EI_DATA]),
            let object = Object(rawValue: bytes[Field.EI_TYPE, endianness: endianness])
        else {
            return nil
        }

        return ELF(
            encoding: encoding,
            endianness: endianness,
            ABI: .init(rawValue: bytes[Field.EI_OSABI]),
            object: object,
            ISA: .init(rawValue: bytes[Field.EI_MACHINE, endianness: endianness])
        )
    }
}

extension ELF {
    static func read(at path: URL) throws -> ELF? {
        let handle = try FileHandle(forReadingFrom: path)
        guard let header = try handle.read(upToCount: minHeaderLength) else {
            return nil
        }
        return ELF.read([UInt8](header))
    }
}
