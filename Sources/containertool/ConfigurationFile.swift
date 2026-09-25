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

import Foundation

/// Defaults loaded from a project-local `containertool.json` configuration file.
///
/// Values from this file are applied after built-in defaults and before environment
/// variables and command-line flags.  Command-line flags take precedence over
/// environment variables, which take precedence over this file.
struct ContainerToolConfiguration: Equatable, Sendable {
    /// Filename searched for in the project directory.
    static let filename = "containertool.json"

    var defaultRegistry: String?
    var repository: String?
    var tag: String?
    var from: String?
    var architecture: String?
    var os: String?
    var defaultUsername: String?
    var defaultPassword: String?

    /// An empty configuration with no values set.
    static let empty = ContainerToolConfiguration()

    /// Loads configuration by searching for ``filename`` starting at `directory`
    /// and walking up parent directories until the file is found or the filesystem
    /// root is reached.
    ///
    /// - Parameter directory: Directory at which to begin the search.
    /// - Returns: The decoded configuration and the URL of the file that was loaded,
    ///   or `nil` if no configuration file was found.
    /// - Throws: If a configuration file exists but cannot be read or decoded.
    static func load(
        startingAt directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> (configuration: ContainerToolConfiguration, url: URL)? {
        guard let url = findConfigurationFile(startingAt: directory) else {
            return nil
        }
        return (try load(from: url), url)
    }

    /// Loads and decodes a configuration file at `url`.
    ///
    /// - Parameter url: Path to a `containertool.json` file.
    /// - Returns: The decoded configuration.
    /// - Throws: If the file cannot be read or is not valid JSON for this schema.
    static func load(from url: URL) throws -> ContainerToolConfiguration {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigurationFileError.unreadable(path: url.path, underlying: error)
        }

        let decoded: FileContents
        do {
            decoded = try JSONDecoder().decode(FileContents.self, from: data)
        } catch {
            throw ConfigurationFileError.invalid(path: url.path, underlying: error)
        }

        return ContainerToolConfiguration(
            defaultRegistry: decoded.defaultRegistry.nonEmpty,
            repository: decoded.repository.nonEmpty,
            tag: decoded.tag.nonEmpty,
            from: decoded.from.nonEmpty,
            architecture: decoded.architecture.nonEmpty,
            os: decoded.os.nonEmpty,
            defaultUsername: decoded.defaultUsername.nonEmpty,
            defaultPassword: decoded.defaultPassword.nonEmpty
        )
    }

    /// Searches for ``filename`` starting at `directory` and walking up toward the root.
    ///
    /// - Parameter directory: Directory at which to begin the search.
    /// - Returns: The URL of the first matching file, or `nil` if none is found.
    static func findConfigurationFile(startingAt directory: URL) -> URL? {
        var current = directory.standardizedFileURL
        let fm = FileManager.default

        while true {
            let candidate = current.appendingPathComponent(filename)
            if fm.isReadableFile(atPath: candidate.path) {
                return candidate
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }
}

enum ConfigurationFileError: Error, CustomStringConvertible, Equatable {
    case unreadable(path: String, underlying: Error)
    case invalid(path: String, underlying: Error)

    var description: String {
        switch self {
        case .unreadable(let path, let underlying):
            return "Unable to read configuration file \(path): \(underlying)"
        case .invalid(let path, let underlying):
            return "Invalid configuration file \(path): \(underlying)"
        }
    }

    static func == (lhs: ConfigurationFileError, rhs: ConfigurationFileError) -> Bool {
        lhs.description == rhs.description
    }
}

extension ContainerToolConfiguration {
    private struct FileContents: Decodable {
        var defaultRegistry: String?
        var repository: String?
        var tag: String?
        var from: String?
        var architecture: String?
        var os: String?
        var defaultUsername: String?
        var defaultPassword: String?
    }
}

extension Optional where Wrapped == String {
    fileprivate var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
