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

import RegexBuilder

// https://github.com/distribution/distribution/blob/v2.7.1/reference/reference.go
// Split the image reference into a registry and a name part.
func splitReference(_ reference: String) throws -> (String?, String) {
    let splits = reference.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
    if splits.count == 0 { throw ImageReference.ValidationError.unexpected("unexpected error") }

    if splits.count == 1 { return (nil, reference) }

    // assert splits == 2
    // Hostname heuristic: contains a '.' or a ':', or is localhost
    if splits[0] != "localhost", !splits[0].contains("."), !splits[0].contains(":") { return (nil, reference) }

    return (String(splits[0]), String(splits[1]))
}

// Split the name into repository and tag parts
// distribution/distribution defines regular expressions which validate names but these seem to be very strict
// and reject names which clients accept
func splitName(_ name: String) throws -> (String, String) {
    let digestSplit = name.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    if digestSplit.count == 2 { return (String(digestSplit[0]), String(digestSplit[1])) }

    let tagSplit = name.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    if tagSplit.count == 0 { throw ImageReference.ValidationError.unexpected("unexpected error") }

    if tagSplit.count == 1 { return (name, "latest") }

    // assert splits == 2
    return (String(tagSplit[0]), String(tagSplit[1]))
}

/// ImageReference points to an image stored on a container registry
public struct ImageReference: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The registry which contains this image
    public var registry: String
    /// The repository which contains this image
    public var repository: Repository
    /// The tag identifying the image.
    public var reference: String

    public enum ValidationError: Error {
        case unexpected(String)
    }

    /// Creates an ImageReference from an image reference string.
    /// - Parameters:
    ///   - reference: The reference to parse.
    ///   - defaultRegistry: The default registry to use if the reference does not include a registry.
    /// - Throws: If `reference` cannot be parsed as an image reference.
    public init(fromString reference: String, defaultRegistry: String = "localhost:5000") throws {
        let (registry, remainder) = try splitReference(reference)
        let (repository, reference) = try splitName(remainder)
        self.registry = registry ?? defaultRegistry
        if self.registry == "docker.io" {
            self.registry = "index.docker.io"  // Special case for docker client, there is no network-level redirect
        }
        // As a special case, official images can be referred to by a single name, such as `swift` or `swift:slim`.
        // moby/moby assumes that these names refer to images in `library`: `library/swift` or `library/swift:slim`.
        // This special case only applies when using Docker Hub, so `example.com/swift` is not expanded `example.com/library/swift`
        if self.registry == "index.docker.io" && !repository.contains("/") {
            self.repository = try Repository("library/\(repository)")
        } else {
            self.repository = try Repository(repository)
        }
        self.reference = reference
    }

    /// Creates an ImageReference from separate registry, repository and reference strings.
    /// Used only in tests.
    /// - Parameters:
    ///   - registry: The registry which stores the image data.
    ///   - repository: The repository within the registry which holds the image.
    ///   - reference: The tag identifying the image.
    init(registry: String, repository: Repository, reference: String) {
        self.registry = registry
        self.repository = repository
        self.reference = reference
    }

    /// Printable description of an ImageReference in a form which can be understood by a runtime
    public var description: String {
        if reference.starts(with: "sha256") {
            return "\(registry)/\(repository)@\(reference)"
        } else {
            return "\(registry)/\(repository):\(reference)"
        }
    }

    /// Printable description of an ImageReference in a form suitable for debugging.
    public var debugDescription: String {
        "ImageReference(registry: \(registry), repository: \(repository), reference: \(reference))"
    }
}

extension ImageReference {
    /// Repository refers a repository (image namespace) on a container registry
    public struct Repository: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        var value: String

        public enum ValidationError: Error, Equatable {
            case emptyString
            case containsUppercaseLetters(String)
            case invalidReferenceFormat(String)
        }

        public init(_ rawValue: String) throws {
            // Reference handling in github.com/distribution reports empty and uppercase as specific errors.
            // All other errors caused are reported as generic format errors.
            guard rawValue.count > 0 else {
                throw ValidationError.emptyString
            }

            if (rawValue.contains { $0.isUppercase }) {
                throw ValidationError.containsUppercaseLetters(rawValue)
            }

            // https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
            let regex = /[a-z0-9]+((\.|_|__|-+)[a-z0-9]+)*(\/[a-z0-9]+((\.|_|__|-+)[a-z0-9]+)*)*/
            if try regex.wholeMatch(in: rawValue) == nil {
                throw ValidationError.invalidReferenceFormat(rawValue)
            }

            value = rawValue
        }

        public var description: String {
            value
        }

        /// Printable description of an ImageReference in a form suitable for debugging.
        public var debugDescription: String {
            "Repository(\(value))"
        }
    }
}
