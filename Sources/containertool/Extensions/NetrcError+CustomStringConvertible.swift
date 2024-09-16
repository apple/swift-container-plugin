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

import Basics

extension Basics.NetrcError: Swift.CustomStringConvertible {
    /// Description of an error in the .netrc file.
    public var description: String {
        switch self {
        case .machineNotFound: return "No entry for host in .netrc"
        case .invalidDefaultMachinePosition: return "Invalid .netrc - 'default' must be the last entry in the file"
        }
    }
}
