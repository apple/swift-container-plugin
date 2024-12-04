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

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Adapted NIOHTTPCompression/HTTPCompression.swift in swift-nio-extras
import VendorCNIOExtrasZlib

func gzip(_ bytes: [UInt8]) -> [UInt8] {
    var stream = z_stream()
    stream.zalloc = nil
    stream.zfree = nil
    stream.opaque = nil

    // Force identical gzip headers to be created on Linux and macOS.
    //
    // RFC1952 defines operating system codes which can be embedded in the gzip header.
    //
    // * Initially, zlib generated a default gzip header with the
    //   OS field set to `Unknown` (255).
    // * https://github.com/madler/zlib/commit/0484693e1723bbab791c56f95597bd7dbe867d03
    //   changed the default to `Unix` (3).
    // * https://github.com/madler/zlib/commit/ce12c5cd00628bf8f680c98123a369974d32df15
    //   changed the default to use a value based on the OS detected
    //   at compile time.  After this, zlib on Linux continued to
    //   use `Unix` (3) whereas macOS started to use `Apple` (19).
    //
    // According to RFC1952 Section 2.3.1.2. (Compliance), `Unknown`
    // 255 should be used by default where the OS on which the file
    // was created is not known.
    //
    // Different versions of zlib might still produce different
    // compressed output for the same input,  but using the same default
    // value removes one one source of differences between platforms.

    let gz_os_unknown = Int32(255)
    var header = gz_header()
    header.os = gz_os_unknown

    let windowBits: Int32 = 15 + 16
    let level = Z_DEFAULT_COMPRESSION
    let memLevel: Int32 = 8
    let rc = CNIOExtrasZlib_deflateInit2(&stream, level, Z_DEFLATED, windowBits, memLevel, Z_DEFAULT_STRATEGY)
    deflateSetHeader(&stream, &header)

    precondition(rc == Z_OK, "Unexpected return from zlib init: \(rc)")

    var inputBuffer = bytes

    // calculate the upper bound size for the output buffer
    let bufferSize = Int(deflateBound(&stream, UInt(inputBuffer.count)))
    var outputBuffer: [UInt8] = .init(repeating: 0, count: bufferSize)

    var count = 0

    inputBuffer.withUnsafeMutableBufferPointer { inputPtr in
        stream.avail_in = UInt32(inputPtr.count)
        stream.next_in = inputPtr.baseAddress!

        outputBuffer.withUnsafeMutableBufferPointer { outputPtr in
            stream.avail_out = UInt32(outputPtr.count)
            stream.next_out = outputPtr.baseAddress!

            let rc = deflate(&stream, Z_FINISH)
            precondition(rc != Z_STREAM_ERROR, "Unexpected return from zlib deflate: \(rc)")
            deflateEnd(&stream)

            count = outputPtr.count - Int(stream.avail_out)
        }
    }

    return Array(outputBuffer[..<count])
}
