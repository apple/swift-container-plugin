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

@main
struct Hello {
    static let hostname = "0.0.0.0"
    static let port = 8080

    static func main() async throws {
        let app = buildApplication(
            configuration: .init(
                address: .hostname(hostname, port: port),
                serverName: "Hummingbird"
            )
        )
        try await app.runService()
    }
}
