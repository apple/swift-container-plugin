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

import Foundation
import HTTPTypes
import struct Crypto.SHA256

// The spec says that Docker- prefix headers are no longer to be used, but also specifies that the registry digest is returned in this header.
extension HTTPField.Name { static let dockerContentDigest = Self("Docker-Content-Digest")! }

/// Calculates the digest of a blob of data.
/// - Parameter data: Blob of data to digest.
/// - Returns: The blob's digest, in the format expected by the distribution protocol.
public func digest(of data: any DataProtocol) -> ImageReference.Digest {
    // SHA256 is required; some registries might also support SHA512
    let hash = SHA256.hash(data: data)
    let digest = hash.compactMap { String(format: "%02x", $0) }.joined()
    return try! ImageReference.Digest("sha256:" + digest)
}
