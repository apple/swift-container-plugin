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
        let faces = [
            "happy-cat-face",
            "slightly-smiling-face",
            "smiling-face-with-sunglasses",
        ]

        guard let resourceURL = Bundle.module.url(forResource: faces.randomElement(), withExtension: "jpg") else {
            throw HTTPError(.internalServerError)
        }

        let image = try Data(contentsOf: resourceURL)

        return Response(
            status: .ok,
            headers: [.contentType: "image/jpg"],
            body: .init(byteBuffer: ByteBuffer(bytes: image))
        )
    }

    let app = Application(
        router: router,
        configuration: configuration,
        logger: Logger(label: "hello-with-resources")
    )

    return app
}
