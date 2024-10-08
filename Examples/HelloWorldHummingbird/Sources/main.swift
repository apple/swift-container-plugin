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

import Foundation
import Hummingbird

let myos = ProcessInfo.processInfo.operatingSystemVersionString

let router = Router()
router.get { request, _ -> String in "Hello World, from Hummingbird on \(myos)\n" }

let app = Application(router: router, configuration: .init(address: .hostname("0.0.0.0", port: 8080)))

try await app.runService()
