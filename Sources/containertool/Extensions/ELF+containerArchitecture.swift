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

extension ELF.ISA {
    /// Converts the ELF architecture to the GOARCH string representation understood by the container runtime.
    /// Unsupported architectures are mapped to nil.
    var containerArchitecture: String? {
        switch self {
        case .x86_64: "amd64"
        case .aarch64: "arm64"
        default: nil
        }
    }
}
