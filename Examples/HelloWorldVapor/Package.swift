// swift-tools-version: 6.0

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

import PackageDescription

let package = Package(
    name: "hello-world",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.102.0")),
        .package(url: "https://github.com/apple/swift-container-plugin", from: "0.4.0"),
    ],
    targets: [.executableTarget(name: "hello-world", dependencies: [.product(name: "Vapor", package: "vapor")])]
)
