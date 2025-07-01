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

import ContainerRegistry

extension HTTPClientError: Swift.CustomStringConvertible {
    /// A human-readable string representing an underlying HTTP protocol error
    public var description: String {
        switch self {
        case .unexpectedStatusCode(let status, _, _):
            return "Registry returned an unexpected HTTP error code: \(status)"
        case .unexpectedContentType(let contentType):
            return "Registry returned an unexpected HTTP content type: \(contentType)"
        case .missingContentType: return "Registry response did not include a content type"
        case .missingResponseHeader(let header):
            return "Registry response did not include an expected header: \(header)"
        case .authenticationChallenge(let challenge, _, _):
            return "Unhandled authentication challenge from registry: \(challenge)"
        case .unauthorized: return "Registry response: unauthorized"
        }
    }
}

extension DistributionErrorCode: Swift.CustomStringConvertible {
    /// A human-readable string representing a distribution protocol error code
    public var description: String { self.rawValue }
}

extension ContainerRegistry.DistributionError: Swift.CustomStringConvertible {
    /// A human-readable string describing an unhandled distribution protocol error
    public var description: String { if let message { return "\(code): \(message)" } else { return "\(code)" } }
}

extension ContainerRegistry.DistributionErrors: Swift.CustomStringConvertible {
    /// A human-readable string describing a collection of unhandled distribution protocol errors
    public var description: String { errors.map { $0.description }.joined(separator: "\n") }
}

extension ContainerRegistry.ImageReference.Repository.ValidationError: Swift.CustomStringConvertible {
    /// A human-readable string describing an image reference validation error
    public var description: String {
        switch self {
        case .emptyString:
            return "Invalid reference format: repository name cannot be empty"
        case .containsUppercaseLetters(let rawValue):
            return "Invalid reference format: repository name (\(rawValue)) must be lowercase"
        case .invalidReferenceFormat(let rawValue):
            return "Invalid reference format: repository name (\(rawValue)) contains invalid characters"
        }
    }
}

extension ContainerRegistry.ImageReference.Tag.ValidationError: Swift.CustomStringConvertible {
    /// A human-readable string describing an image reference validation error
    public var description: String {
        switch self {
        case .emptyString:
            return "Invalid reference format: tag cannot be empty"
        case .tooLong(let rawValue):
            return "Invalid reference format: tag (\(rawValue)) is too long"
        case .invalidReferenceFormat(let rawValue):
            return "Invalid reference format: tag (\(rawValue)) contains invalid characters"
        }
    }
}

extension ContainerRegistry.ImageReference.Digest.ValidationError: Swift.CustomStringConvertible {
    /// A human-readable string describing an image reference validation error
    public var description: String {
        switch self {
        case .emptyString:
            return "Invalid reference format: digest cannot be empty"
        case .tooLong(let rawValue):
            return "Invalid reference format: digest (\(rawValue)) is too long"
        case .invalidReferenceFormat(let rawValue):
            return "Invalid reference format: digest (\(rawValue)) is not a valid digest"
        }
    }
}
