//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import Foundation
import Testing

@testable import containertool

@Suite struct AuthenticationOptionsTests {
    @Test func parsesDefaultPasswordFromStdinFlag() throws {
        let defaults = try ContainerTool.AuthenticationOptions.parse([])
        #expect(!defaults.defaultPasswordFromStdin)

        let parsed = try ContainerTool.AuthenticationOptions.parse(["--default-password-from-stdin"])
        #expect(parsed.defaultPasswordFromStdin)
    }

    @Test func rejectsConflictingPasswordFlags() throws {
        do {
            _ = try ContainerTool.AuthenticationOptions.parse([
                "--default-password-from-stdin", "--default-password", "secret",
            ])
            Issue.record("Expected conflicting --default-password and --default-password-from-stdin to fail validation")
        } catch {
            #expect(
                ContainerTool.AuthenticationOptions.message(for: error)
                    == "--default-password and --default-password-from-stdin cannot be specified together."
            )
        }

        do {
            _ = try ContainerTool.AuthenticationOptions.parse([
                "--default-password-from-stdin", "--password", "secret",
            ])
            Issue.record("Expected conflicting --password and --default-password-from-stdin to fail validation")
        } catch {
            #expect(
                ContainerTool.AuthenticationOptions.message(for: error)
                    == "--password and --default-password-from-stdin cannot be specified together."
            )
        }
    }

    @Test func readsPasswordFromStdin() throws {
        try withPipeData(Data("secret\n".utf8)) { handle in
            let password = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            #expect(password == "secret")
        }

        try withPipeData(Data(" p@ss word \r\n".utf8)) { handle in
            let password = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            #expect(password == " p@ss word ")
        }

        try withPipeData(Data("no-trailing-newline".utf8)) { handle in
            let password = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            #expect(password == "no-trailing-newline")
        }
    }

    @Test func rejectsEmptyOrInvalidStdinPassword() throws {
        try withPipeData(Data()) { handle in
            #expect(throws: ValidationError.self) {
                _ = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            }
        }

        try withPipeData(Data("\r\n".utf8)) { handle in
            #expect(throws: ValidationError.self) {
                _ = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            }
        }

        try withPipeData(Data([0xFF, 0xFE])) { handle in
            #expect(throws: ValidationError.self) {
                _ = try ContainerTool.AuthenticationOptions.readPassword(from: handle)
            }
        }
    }
}

private func withPipeData(_ data: Data, _ body: (FileHandle) throws -> Void) throws {
    let pipe = Pipe()
    try pipe.fileHandleForWriting.write(contentsOf: data)
    try pipe.fileHandleForWriting.close()
    defer { try? pipe.fileHandleForReading.close() }
    try body(pipe.fileHandleForReading)
}
