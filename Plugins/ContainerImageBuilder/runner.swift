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

/// Error code returned if the process terminates because of an uncaught signal.
public enum ExitCode: Error { case rawValue(Int32) }

/// Runs `command` with the given arguments and environment variables, capturing standard output and standard error.
/// - Parameters:
///   - command: The URL for the executable.
///   - arguments: An array of arguments to supply to the executable.
///   - environment: A dictionary of environment variables to supply to the executable.
///   - outputPipe: A Pipe to which to send anything the executable writes to standard output.
///   - errorPipe: A Pipe to which to send anything the executable writes to standard error.
/// - Throws: `ExitCode` if the process terminates because of an uncaught signal.
public func run(
    command: URL,
    arguments: [String],
    environment: [String: String]? = nil,
    outputPipe: Pipe? = nil,
    errorPipe: Pipe? = nil
) async throws {
    let task = Process()

    task.executableURL = command
    task.arguments = arguments
    task.environment = environment
    if let outputPipe { task.standardOutput = outputPipe }
    if let errorPipe { task.standardError = errorPipe }

    return try await withCheckedThrowingContinuation { continuation in
        task.terminationHandler = { process in
            switch process.terminationReason {
            case .uncaughtSignal:
                let error = ExitCode.rawValue(process.terminationStatus)
                continuation.resume(throwing: error)
            case .exit: continuation.resume(returning: ())
            @unknown default:
                // This point should be unreachable.
                continuation.resume(returning: ())
            }
        }

        do { try task.run() } catch { continuation.resume(throwing: error) }
    }
}
