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
import Hummingbird
import Logging

let myos = ProcessInfo.processInfo.operatingSystemVersionString

func buildApplication(configuration: ApplicationConfiguration) -> some ApplicationProtocol {
    let router = Router()
    router.addMiddleware { LogRequestsMiddleware(.info) }
    router.get("/") { _, _ in
        "Hello World, from Hummingbird on \(myos)\n"
    }

    let app = Application(
        router: router,
        configuration: configuration,
        logger: Logger(label: "HelloWorldHummingbird")
    )

    return app
}
