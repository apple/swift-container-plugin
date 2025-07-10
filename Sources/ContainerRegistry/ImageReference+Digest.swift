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
import struct Crypto.SHA512

// The distribution spec says that Docker- prefix headers are no longer to be used,
// but also specifies that the registry digest is returned in this header.
// https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
extension HTTPField.Name {
    static let dockerContentDigest = Self("Docker-Content-Digest")!
}

extension ImageReference.Digest {
    /// Calculate the digest of a blob of data.
    /// - Parameters:
    ///   - data: Blob of data to digest.
    ///   - algorithm: Digest algorithm to use.
    public init<Blob: DataProtocol>(
        of data: Blob,
        algorithm: ImageReference.Digest.Algorithm = .sha256
    ) {
        // SHA256 is required; some registries might also support SHA512
        switch algorithm {
        case .sha256:
            let hash = SHA256.hash(data: data)
            let digest = hash.compactMap { String(format: "%02x", $0) }.joined()
            try! self.init("sha256:" + digest)

        case .sha512:
            let hash = SHA512.hash(data: data)
            let digest = hash.compactMap { String(format: "%02x", $0) }.joined()
            try! self.init("sha512:" + digest)
        }
    }
}
