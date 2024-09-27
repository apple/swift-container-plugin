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
import Vapor

let myos = ProcessInfo.processInfo.operatingSystemVersionString

let app = try Application(.detect())
app.http.server.configuration.hostname = "0.0.0.0"
defer { app.shutdown() }

app.get { _ in "Hello World, from \(myos)\n" }

try app.run()
