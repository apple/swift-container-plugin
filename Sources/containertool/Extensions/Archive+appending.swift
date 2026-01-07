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

import class Foundation.FileManager
import struct Foundation.Data
import struct Foundation.FileAttributeType
import struct Foundation.URL

import Tar

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

extension Archive {
    /// Append a file or directory tree to the archive.   Directory trees are appended recursively.
    /// Parameters:
    /// - root: The path to the file or directory to add.
    /// Returns:  A new archive made by appending `root` to the receiver.
    public func appendingRecursively(atPath root: String) throws -> Self {
        let url = URL(fileURLWithPath: root)
        if url.isDirectory {
            return try self.appendingDirectoryTree(at: url)
        } else {
            return try self.appendingFile(at: url)
        }
    }

    /// Append a single file to the archive.
    /// Parameters:
    /// - path: The path to the file to add.
    /// Returns:  A new archive made by appending `path` to the receiver.
    func appendingFile(at path: URL) throws -> Self {
        try self.appendingFile(name: path.lastPathComponent, data: try [UInt8](Data(contentsOf: path)))
    }

    func appendingFile(at path: URL, to destinationPath: URL) throws -> Self {
        var ret = self
        let data = try [UInt8](Data(contentsOf: path))
        let components = destinationPath.pathComponents
        precondition(!components.isEmpty, "Destination path is empty")
        for i in 1..<components.count - 1 {
            let directoryPath = components[..<i].joined(separator: "/")
            try ret.appendDirectory(name: directoryPath)
        }

        try ret.appendFile(name: destinationPath.path(), data: data)
        return ret
    }

    /// Recursively append a single directory tree to the archive.
    /// Parameters:
    /// - root: The path to the directory to add.
    /// Returns:  A new archive made by appending `root` to the receiver.
    func appendingDirectoryTree(at root: URL, to destinationPath: URL = URL(filePath: "/")) throws -> Self {
        var ret = self

        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else {
            throw ("Unable to read \(root.path)")
        }

        for case let subpath as String in enumerator {
            // https://developer.apple.com/documentation/foundation/filemanager/1410452-attributesofitem
            // https://developer.apple.com/documentation/foundation/fileattributekey

            guard let filetype = enumerator.fileAttributes?[.type] as? FileAttributeType else {
                throw ("Unable to get file type for \(subpath)")
            }

            let subpath = destinationPath.appending(path: subpath).path()
            switch filetype {
            case .typeRegular:
                let resource = try [UInt8](Data(contentsOf: root.appending(path: subpath)))
                try ret.appendFile(name: subpath, prefix: root.lastPathComponent, data: resource)

            case .typeDirectory:
                try ret.appendDirectory(name: subpath, prefix: root.lastPathComponent)

            default:
                throw "Resource file \(subpath) of type \(filetype) is not supported"
            }
        }

        return ret
    }
}
