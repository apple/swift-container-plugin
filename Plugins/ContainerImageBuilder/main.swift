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
import PackagePlugin

enum PluginError: Error {
    case argumentError(String)
    case buildError
    case productNotExecutable(String)
}

extension PluginError: CustomStringConvertible {
    /// Description of the error
    public var description: String {
        switch self {
        case let .argumentError(s): return s
        case .buildError: return "Build failed"
        case let .productNotExecutable(productName):
            return "\(productName) is not an executable product and cannot be used as a container entrypoint."
        }
    }
}

@main struct ContainerImageBuilder: CommandPlugin {
    /// Main entry point of the plugin.
    /// - Parameters:
    ///   - context: A `PluginContext` which gives access to Swift Package Manager.
    ///   - arguments: Additional command line arguments for the plugin.
    /// - Throws: If the product cannot be built or if packaging and uploading it fails.
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var extractor = ArgumentExtractor(arguments)
        if extractor.extractFlag(named: "help") > 0 {
            print(
                """
                USAGE: build-container-image <options>

                OPTIONS
                  --product      Product to include in the image
                  --resources    Directory of resources to include in the image

                Other arguments are passed to the containertool helper.
                """
            )
            return
        }

        // The plugin must extract the --product argument, if present, so it can ask Swift Package Manager to rebuild it.
        // All other arguments can be passed straight through to the helper tool.
        //
        // * If --product is specified on the command line, use it.
        // * Otherwise, if the package only defines one product, use that.
        // * Otherwise there are multiple possible products, so the user must choose which one to use.

        let executableProducts = context.package.products.filter { $0 is ExecutableProduct }.map { $0.name }

        let productName: String
        if let productArg = extractor.extractOption(named: "product").first {
            guard executableProducts.contains(productArg) else { throw PluginError.productNotExecutable(productArg) }
            productName = productArg
        } else if executableProducts.count == 1 {
            productName = executableProducts[0]
        } else {
            throw PluginError.argumentError("Please specify which executable product to include in the image")
        }

        // Ask the plugin host (SwiftPM or an IDE) to build our product.
        Diagnostics.remark("Building product: \(productName)")
        let result = try packageManager.build(
            .product(productName),
            parameters: .init(configuration: .inherit, echoLogs: true)
        )

        // Check the result. Ideally this would report more details.
        guard result.succeeded else { throw PluginError.buildError }

        // Get the list of built executables from the build result.
        let builtExecutables = result.builtArtifacts.filter { $0.kind == .executable }

        for built in builtExecutables { Diagnostics.remark("Built product: \(built.url.path)") }

        let resourcesBundle = builtExecutables[0].url
            .deletingLastPathComponent()
            .appendingPathComponent(
                "\(context.package.displayName)_\(productName).resources"
            )
        
        var resources = [String]()
        if FileManager.default.fileExists(atPath: resourcesBundle.path) {
            resources.append(resourcesBundle.path)
        }

        for resource in extractor.extractOption(named: "resources") {
            let paths = resource.split(separator: ":", maxSplits: 1)
            if paths.count >= 1 && !FileManager.default.fileExists(atPath: String(paths[0])) {
                throw PluginError.argumentError("Resource directory \(resource) does not exist")
            }
            resources.append(resource)
        }

        // Run a command line helper to upload the image
        let helperURL = try context.tool(named: "containertool").url
        let helperArgs =
            resources.map { "--resources=\($0)" }
            + builtExecutables.map { $0.url.path }
            + extractor.remainingArguments
        let helperEnv = ProcessInfo.processInfo.environment.filter { $0.key.starts(with: "CONTAINERTOOL_") }

        let err = Pipe()

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                enum LoggingState {
                    // Normal output is logged at 'progress' level.
                    case progress

                    // If an error is detected, all output from that point onwards is logged at 'error' level, which is always printed.
                    // Errors are reported even without the --verbose flag and cause the build to return a nonzero exit code.
                    case error

                    func log(_ msg: String) {
                        let trimmed = msg.trimmingCharacters(in: .newlines)
                        switch self {
                        case .progress: Diagnostics.progress(trimmed)
                        case .error: Diagnostics.error(trimmed)
                        }
                    }
                }

                var buf = ""
                var logger = LoggingState.progress

                for try await line in err.lines {
                    buf.append(line)

                    guard let (before, after) = buf.splitOn(first: "\n") else {
                        continue
                    }

                    var msg = before
                    buf = String(after)

                    let errorLabel = "Error: "  // SwiftArgumentParser adds this prefix to all errors which bubble up
                    if msg.starts(with: errorLabel) {
                        logger = .error
                        msg.trimPrefix(errorLabel)
                    }

                    logger.log(String(msg))
                }

                // Print any leftover output in the buffer, in case the child exited without sending a final newline.
                if !buf.isEmpty {
                    logger.log(buf)
                }
            }

            group.addTask {
                try await run(command: helperURL, arguments: helperArgs, environment: helperEnv, errorPipe: err)
            }
        }
    }
}

extension Collection where Element: Equatable {
    func splitOn(first element: Element) -> (before: SubSequence, after: SubSequence)? {
        guard let idx = self.firstIndex(of: element) else {
            return nil
        }

        return (self[..<idx], self[idx...].dropFirst())
    }
}
