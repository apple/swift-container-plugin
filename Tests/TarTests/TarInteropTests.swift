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

import class Foundation.Pipe
import class Foundation.Process

import Testing
@testable import Tar

@Suite struct TarInteropTests {
    // Use the system `tar` program to read the contents of a tar archive.
    // - Parameters input: A stream of bytes to be interpreted as a tar archive
    // - Returns: The output of the `tar` program.
    func tarListContents(_ input: [UInt8]) async throws -> String {
        let inPipe = Pipe()
        let outPipe = Pipe()

        try inPipe.fileHandleForWriting.write(contentsOf: input)
        inPipe.fileHandleForWriting.closeFile()

        let p = Process()
        p.executableURL = .init(fileURLWithPath: "/usr/bin/env")
        p.environment = ["LC_ALL": "C"]  // Avoid locale-specific differences in output formatting
        p.arguments = ["bsdtar", "-t", "-v", "-f", "-"]
        p.standardInput = inPipe
        p.standardOutput = outPipe
        try p.run()

        // bsdtar console listing includes a trailing newline
        let output = try #require(try outPipe.fileHandleForReading.readToEnd())
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test func testSingle4BFile() async throws {
        let data = "test"
        let result = try tar([UInt8](data.utf8), filename: "filename")
        #expect(result.count == headerSize + blockSize + trailerSize)

        let output = try await tarListContents(result)
        #expect(output == "-r-xr-xr-x  0 0      0           4 Jan  1  1970 filename")
    }

    @Test func testSingleEmptyFile() async throws {
        // An empty tar file created by bsd tar consumes 1536 bytes:
        // % tar -c --numeric-owner -f empty.tar empty
        // % cat empty.tar
        // empty000644 000765 000000 00000000000 14737460101 010320 0ustar00000000 000000 %
        // % wc -c empty.tar
        //   1536 empty.tar
        // This means 3 blocks are consumed: one for the file header and two for the file trailer;  no blocks are stored for the empty file

        let data = ""
        let result = try tar([UInt8](data.utf8), filename: "filename")
        #expect(result.count == headerSize + trailerSize)

        let output = try await tarListContents(result)
        #expect(output == "-r-xr-xr-x  0 0      0           0 Jan  1  1970 filename")
    }

    // Test a degenerate case where the archive has no trailer
    @Test func testEmptyFileHeaderNoTrailer() async throws {
        var hdr: [UInt8] = []
        hdr.append(contentsOf: try TarHeader(name: "filename1", size: 0).bytes)

        // No file data, no padding, no end of file marker
        #expect(hdr.count == headerSize)

        // bsdtar tolerates the lack of end of file marker
        let output = try await tarListContents(hdr)
        #expect(output == "-r-xr-xr-x  0 0      0           0 Jan  1  1970 filename1")
    }

    @Test func testEmptyFileHeaderWithTrailer() async throws {
        var hdr = try TarHeader(name: "filename1", size: 0).bytes

        // No file data, no padding

        // Append end of file marker
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        hdr.append(contentsOf: marker)

        let output = try await tarListContents(hdr)
        #expect(output == "-r-xr-xr-x  0 0      0           0 Jan  1  1970 filename1")
    }

    // Test tar's reaction to a multi-file archive with an unnecessary block of
    // zeros (caused by bad padding).   Tar only sees the first archive member.
    @Test func testEmptyFileHeaderMultipleBadPaddingWithTrailer() async throws {
        let data: [UInt8] = []
        var archive: [UInt8] = []

        // First archive member, with bad padding.  An empty file should not be padded
        // to 512 bytes because this adds a completely empty block which tar interprets
        // as end of file.
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 0).bytes)
        archive.append(contentsOf: data)
        let padding1 = [UInt8](repeating: 0, count: 512 - (data.count % 512))
        archive.append(contentsOf: padding1)

        // Second archive member, also with bad padding.
        archive.append(contentsOf: try TarHeader(name: "filename2", size: 0).bytes)
        archive.append(contentsOf: data)
        let padding2 = [UInt8](repeating: 0, count: 512 - (data.count % 512))
        archive.append(contentsOf: padding2)

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 6 * 512)  // 6 blocks: header, padding, header, padding, eof-marker

        let output = try await tarListContents(archive)

        // bsdtar only sees the first archive member.   Although the archive
        // file end marker is usually two blocks of zeros, here a single block
        // of zeros is interpreted as end of file.
        let expected =
            """
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 filename1
            """

        #expect(output == expected)
    }

    @Test func testEmptyFileHeaderMultipleWithTrailer() async throws {
        let data: [UInt8] = []
        var archive: [UInt8] = []

        // First archive member
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 0).bytes)
        archive.append(contentsOf: data)

        // Second archive member
        archive.append(contentsOf: try TarHeader(name: "filename2", size: 0).bytes)
        archive.append(contentsOf: data)

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 4 * 512)  // 4 blocks: header, header, eof-marker

        let output = try await tarListContents(archive)

        let expected =
            """
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 filename1
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 filename2
            """

        // N.B.: bsdtar output always includes a trailing newline
        #expect(output == expected)
    }

    @Test func testDirectory() async throws {
        var archive: [UInt8] = []

        // First archive member
        archive.append(contentsOf: try TarHeader(name: "dir1", typeflag: .DIRTYPE).bytes)

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 3 * 512)  // header, eof-marker

        let output = try await tarListContents(archive)

        let expected =
            """
            dr-xr-xr-x  0 0      0           0 Jan  1  1970 dir1
            """

        // N.B.: bsdtar output always includes a trailing newline
        #expect(output == expected)
    }

    @Test func testDirectoryAndFiles() async throws {
        var archive: [UInt8] = []

        // Directory
        archive.append(contentsOf: try TarHeader(name: "dir1", typeflag: .DIRTYPE).bytes)

        // File at root of archive
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 0).bytes)

        // File in the directory
        archive.append(contentsOf: try TarHeader(name: "dir1/filename2", size: 0).bytes)

        // Another file in the directory, using `prefix`
        archive.append(contentsOf: try TarHeader(name: "filename3", size: 0, prefix: "dir1").bytes)

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 6 * 512)  //  header, header, header, eof-marker

        let output = try await tarListContents(archive)

        // It's common to see directories immediately followed by the files which they contain,
        // but nothing about the tar format requires that
        let expected =
            """
            dr-xr-xr-x  0 0      0           0 Jan  1  1970 dir1
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 filename1
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 dir1/filename2
            -r-xr-xr-x  0 0      0           0 Jan  1  1970 dir1/filename3
            """

        // N.B.: bsdtar output always includes a trailing newline
        #expect(output == expected)
    }

    @Test func testDirectoryAndFilesWithContents() async throws {
        var archive: [UInt8] = []

        // Directory
        archive.append(contentsOf: try TarHeader(name: "dir1", typeflag: .DIRTYPE).bytes)

        // File at root of archive
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 4).bytes)

        // There's no real need to write actual data, as long as we have a block
        archive.append(contentsOf: [UInt8]("abcd".utf8))
        archive.append(contentsOf: [UInt8](repeating: 0, count: padding(4)))

        // File in the directory
        archive.append(contentsOf: try TarHeader(name: "dir1/filename2", size: 4).bytes)
        archive.append(contentsOf: [UInt8]("abcd".utf8))
        archive.append(contentsOf: [UInt8](repeating: 0, count: padding(4)))

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 7 * 512)  //  header, header, data, header, data, eof-marker

        let output = try await tarListContents(archive)

        // It's common to see directories immediately followed by the files which they contain,
        // but nothing about the tar format requires that
        let expected =
            """
            dr-xr-xr-x  0 0      0           0 Jan  1  1970 dir1
            -r-xr-xr-x  0 0      0           4 Jan  1  1970 filename1
            -r-xr-xr-x  0 0      0           4 Jan  1  1970 dir1/filename2
            """

        // N.B.: bsdtar output always includes a trailing newline
        #expect(output == expected)
    }

    // If the same filename is added several times, all of them appear in the listing, and all of them are extracted.
    // Later instances overwrite earlier instances.
    //
    //    % echo foo > foo
    //    % tar cvf archive foo
    //    a foo
    //    % wc -c archive
    //    2048 archive    # 1 header block, 1 data block, 2 end of archive blocks
    //    % tar tvf archive
    //    -rw-r--r--  0 user  staff       4 28 Feb 15:55 foo
    //
    //    % echo bar > foo
    //    % tar rvf archive foo
    //    a foo
    //    % wc -c archive
    //    3072 archive    # 1 header block, 1 data block, 1 header block, 1 data block, 2 end of archive blocks
    //    % tar tvf archive
    //    -rw-r--r--  0 user  staff       4 28 Feb 15:55 foo
    //    -rw-r--r--  0 user  staff       4 28 Feb 15:55 foo
    //
    //    % rm foo
    //    % tar xvf archive
    //    x foo
    //    x foo
    //    % cat foo
    //    bar

    @Test func testDuplicateMemberNames() async throws {
        var archive: [UInt8] = []

        // First file
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 4).bytes)
        archive.append(contentsOf: [UInt8]("abcd".utf8))
        archive.append(contentsOf: [UInt8](repeating: 0, count: padding(4)))

        // Replacement file
        archive.append(contentsOf: try TarHeader(name: "filename1", size: 8).bytes)
        archive.append(contentsOf: [UInt8]("abcdefgh".utf8))
        archive.append(contentsOf: [UInt8](repeating: 0, count: padding(8)))

        // End of file marker - 2 empty blocks
        let marker = [UInt8](repeating: 0, count: 2 * 512)
        archive.append(contentsOf: marker)

        // Check length - tar will ignore trailing data and some errors within the archive file
        #expect(archive.count == 6 * 512)  //  header, data, header, data, eof-marker

        let output = try await tarListContents(archive)

        let expected =
            """
            -r-xr-xr-x  0 0      0           4 Jan  1  1970 filename1
            -r-xr-xr-x  0 0      0           8 Jan  1  1970 filename1
            """

        // N.B.: bsdtar output always includes a trailing newline
        #expect(output == expected)
    }
}
