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
    name: "swift-container-plugin",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "containertool", targets: ["containertool"]),
        .plugin(name: "ContainerImageBuilder", targets: ["ContainerImageBuilder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ContainerRegistry",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .target(
                    name: "Basics"  // AuthorizationProvider
                ),
            ]
        ),
        .executableTarget(
            name: "containertool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .target(name: "ContainerRegistry"), .target(name: "VendorCNIOExtrasZlib"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            // Vendored from https://github.com/apple/swift-nio-extras
            name: "VendorCNIOExtrasZlib",
            dependencies: [],
            path: "Vendor/github.com/apple/swift-nio-extras/Sources/CNIOExtrasZlib",
            linkerSettings: [.linkedLibrary("z")]
        ),
        .target(
            // Vendored from https://github.com/apple/swift-package-manager with modifications
            name: "Basics",
            path: "Vendor/github.com/apple/swift-package-manager/Sources/Basics"
        ),
        .plugin(
            name: "ContainerImageBuilder",
            capability: .command(
                intent: .custom(
                    verb: "build-container-image",
                    description: "Builds a container image for the specified target"
                ),
                permissions: [
                    .allowNetworkConnections(
                        // scope: .all(ports: [443, 5000, 8080, 70000]),
                        scope: .all(),
                        reason: "This command publishes images to container registries over the network"
                    )
                ]
            ),
            dependencies: [.target(name: "containertool")]
        ),
        // Empty target that builds the DocC catalog at /ContainerImageBuilderPluginDocumentation/ContainerImageBuilder.docc.
        // The ContainerImageBuilder catalog includes high-level, user-facing documentation about using
        // the ContainerImageBuilder plugin from the command-line.
        .target(
            name: "ContainerImageBuilderPlugin",
            path: "Sources/ContainerImageBuilderPluginDocumentation",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ContainerRegistryTests",
            dependencies: [.target(name: "ContainerRegistry")],
            resources: [.process("Resources")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
