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

/// A text output stream which writes to standard error
struct StdErrOutputStream: TextOutputStream {
    /// Writes a string to standard error.
    /// - Parameter string: String to be written.
    public mutating func write(_ string: String) { fputs(string, stderr) }
}

/// Logs a message to standard error.
/// - Parameter message: Message to be logged.
public func log(_ message: String) {
    var stdError = StdErrOutputStream()
    print(message, to: &stdError)
}
