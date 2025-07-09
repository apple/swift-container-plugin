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
import ArgumentParser
import Basics
import ContainerRegistry

extension Swift.String: Swift.Error {}

enum AllowHTTP: String, ExpressibleByArgument, CaseIterable { case source, destination, both }

@main struct ContainerTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "containertool",
        abstract: "Build and publish a container image"
    )

    @Argument(help: "Executable to package")
    private var executable: String

    /// Options controlling the locations of the source and destination images
    struct RepositoryOptions: ParsableArguments {
        @Option(help: "The default container registry to use when the image reference doesn't specify one")
        var defaultRegistry: String?

        @Option(help: "The name and optional tag for the generated container image")
        var repository: String?

        @Option(help: "The tag for the generated container image")
        var tag: String?

        @Option(help: "The base container image name and optional tag")
        var from: String?
    }

    @OptionGroup(title: "Source and destination repository options")
    var repositoryOptions: RepositoryOptions

    /// Options controlling how the destination image is built
    struct ImageBuildOptions: ParsableArguments {
        @Option(help: "Directory of resources to include in the image")
        var resources: [String] = []
    }

    @OptionGroup(title: "Image build options")
    var imageBuildOptions: ImageBuildOptions

    // Options controlling the destination image's runtime configuration
    struct ImageConfigurationOptions: ParsableArguments {
        @Option(help: "CPU architecture")
        var architecture: String?

        @Option(help: "Operating system")
        var os: String?
    }

    @OptionGroup(title: "Image configuration options")
    var imageConfigurationOptions: ImageConfigurationOptions

    /// Options controlling how containertool authenticates to registries
    struct AuthenticationOptions: ParsableArguments {
        @Option(
            help: ArgumentHelp(
                "[DEPRECATED] Default username, used if there are no matching entries in .netrc. Use --default-username instead.",
                visibility: .private
            )
        )
        var username: String?

        @Option(help: "Default username, used if there are no matching entries in .netrc")
        var defaultUsername: String?

        @Option(
            help: ArgumentHelp(
                "[DEPRECATED] Default password, used if there are no matching entries in .netrc.   Use --default-password instead.",
                visibility: .private
            )
        )
        var password: String?

        @Option(help: "The default password to use if the tool can't find a matching entry in .netrc")
        var defaultPassword: String?

        @Flag(inversion: .prefixedEnableDisable, exclusivity: .exclusive, help: "Load credentials from a netrc file")
        var netrc: Bool = true

        @Option(help: "Specify the netrc file path")
        var netrcFile: String?

        @Option(help: "Connect to the registry using plaintext HTTP")
        var allowInsecureHttp: AllowHTTP?

        mutating func validate() throws {
            // The `--username` and `--password` options present v1.0 were deprecated and replaced by more descriptive
            // `--default-username` and `--default-password`.  The old names are still accepted, but specifying both the old
            // and the new names at the same time is ambiguous and causes an error.
            if username != nil {
                guard defaultUsername == nil else {
                    throw ValidationError(
                        "--default-username and --username cannot be specified together.   --username is deprecated, please use --default-username instead."
                    )
                }

                log("Deprecation warning: --username is deprecated, please use --default-username instead.")
                defaultUsername = username
            }

            if password != nil {
                guard defaultPassword == nil else {
                    throw ValidationError(
                        "--default-password and --password cannot be specified together.   --password is deprecated, please use --default-password instead."
                    )
                }

                log("Deprecation warning: --password is deprecated, please use --default-password instead.")
                defaultPassword = password
            }
        }
    }

    @OptionGroup(title: "Authentication options")
    var authenticationOptions: AuthenticationOptions

    // General options

    @Flag(name: .shortAndLong, help: "Verbose output")
    private var verbose: Bool = false

    func run() async throws {
        // MARK: Apply defaults for unspecified configuration flags

        let env = ProcessInfo.processInfo.environment

        let defaultRegistry = repositoryOptions.defaultRegistry ?? env["CONTAINERTOOL_DEFAULT_REGISTRY"] ?? "docker.io"
        guard let repository = repositoryOptions.repository ?? env["CONTAINERTOOL_REPOSITORY"] else {
            throw ValidationError(
                "Please specify the destination repository using --repository or CONTAINERTOOL_REPOSITORY"
            )
        }

        let username = authenticationOptions.defaultUsername ?? env["CONTAINERTOOL_DEFAULT_USERNAME"]
        let password = authenticationOptions.defaultPassword ?? env["CONTAINERTOOL_DEFAULT_PASSWORD"]
        let from = repositoryOptions.from ?? env["CONTAINERTOOL_BASE_IMAGE"] ?? "swift:slim"
        let os = imageConfigurationOptions.os ?? env["CONTAINERTOOL_OS"] ?? "linux"

        // Try to detect the architecture of the application executable so a suitable base image can be selected.
        // This reduces the risk of accidentally creating an image which stacks an aarch64 executable on top of an x86_64 base image.
        let executableURL = URL(fileURLWithPath: executable)
        let elfheader = try ELF.read(at: executableURL)

        let architecture =
            imageConfigurationOptions.architecture
            ?? env["CONTAINERTOOL_ARCHITECTURE"]
            ?? elfheader?.ISA.containerArchitecture
            ?? "amd64"
        if verbose { log("Base image architecture: \(architecture)") }

        // MARK: Load netrc

        let authProvider: AuthorizationProvider?
        if !authenticationOptions.netrc {
            authProvider = nil
        } else if let netrcFile = authenticationOptions.netrcFile {
            guard FileManager.default.fileExists(atPath: netrcFile) else {
                throw "\(netrcFile) not found"
            }
            let customNetrc = URL(fileURLWithPath: netrcFile)
            authProvider = try NetrcAuthorizationProvider(customNetrc)
        } else {
            let defaultNetrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".netrc")
            authProvider = try NetrcAuthorizationProvider(defaultNetrc)
        }

        // MARK: Create registry clients

        let baseImage = try ImageReference(fromString: from, defaultRegistry: defaultRegistry)
        let destinationImage = try ImageReference(fromString: repository, defaultRegistry: defaultRegistry)

        // The base image may be stored on a different registry to the final destination, so two clients are needed.
        // `scratch` is a special case and requires no source client.
        let source: RegistryClient?
        if from == "scratch" {
            source = nil
        } else {
            source = try await RegistryClient(
                registry: baseImage.registry,
                insecure: authenticationOptions.allowInsecureHttp == .source
                    || authenticationOptions.allowInsecureHttp == .both,
                auth: .init(username: username, password: password, auth: authProvider)
            )
            if verbose { log("Connected to source registry: \(baseImage.registry)") }
        }

        let destination = try await RegistryClient(
            registry: destinationImage.registry,
            insecure: authenticationOptions.allowInsecureHttp == .destination
                || authenticationOptions.allowInsecureHttp == .both,
            auth: .init(username: username, password: password, auth: authProvider)
        )

        if verbose { log("Connected to destination registry: \(destinationImage.registry)") }
        if verbose { log("Using base image: \(baseImage)") }

        // MARK: Build the image

        let finalImage = try await publishContainerImage(
            baseImage: baseImage,
            destinationImage: destinationImage,
            source: source,
            destination: destination,
            architecture: architecture,
            os: os,
            resources: imageBuildOptions.resources,
            tag: repositoryOptions.tag,
            verbose: verbose,
            executableURL: executableURL
        )

        print(finalImage)
    }
}
