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

    let windowBits: Int32 = 15 + 16
    let level = Z_DEFAULT_COMPRESSION
    let memLevel: Int32 = 8
    let rc = CNIOExtrasZlib_deflateInit2(&stream, level, Z_DEFLATED, windowBits, memLevel, Z_DEFAULT_STRATEGY)

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
