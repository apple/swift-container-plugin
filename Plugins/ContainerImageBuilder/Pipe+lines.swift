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

extension Pipe {
    var lines: AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            self.fileHandleForReading.readabilityHandler = { [unowned self] fileHandle in
                // Reading blocks until data is available.  We should not see 0 byte reads.
                let data = fileHandle.availableData
                if data.isEmpty {  // EOF
                    continuation.finish()

                    // Clean up the handler to prevent repeated calls and continuation finishes for the same process.
                    self.fileHandleForReading.readabilityHandler = nil
                    return
                }

                let s = String(data: data, encoding: .utf8)!
                continuation.yield(s)
            }
        }
    }
}
