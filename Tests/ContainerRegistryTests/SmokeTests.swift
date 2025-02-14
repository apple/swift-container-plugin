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

import class Foundation.ProcessInfo
import ContainerRegistry
import Testing

struct SmokeTests {
    // These are basic tests to exercise the main registry operations.
    // The tests assume that a fresh, empty registry instance is available at
    // http://$REGISTRY_HOST:$REGISTRY_PORT

    var client: RegistryClient
    let registryHost = ProcessInfo.processInfo.environment["REGISTRY_HOST"] ?? "localhost"
    let registryPort = ProcessInfo.processInfo.environment["REGISTRY_PORT"] ?? "5000"

    /// Registry client fixture created for each test
    init() async throws {
        client = try await RegistryClient(registry: "\(registryHost):\(registryPort)", insecure: true)
    }

    @Test func testGetTags() async throws {
        let repository = "testgettags"

        // registry:2 does not validate the contents of the config or image blobs
        // so a smoke test can use simple data.   Other registries are not so forgiving.
        let config_descriptor = try await client.putBlob(
            repository: repository,
            mediaType: "application/vnd.docker.container.image.v1+json",
            data: "testconfiguration".data(using: .utf8)!
        )

        // Initially there will be no tags
        do {
            _ = try await client.getTags(repository: repository)
            Issue.record("Getting tags for an untagged blob should have thrown an error")
        } catch {
            // Expect to receive an error
        }

        // We need to create a manifest referring to the blob, which can then be tagged
        let test_manifest = ImageManifest(
            schemaVersion: 2,
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            config: config_descriptor,
            layers: []
        )

        // After setting a tag, we should be able to retrieve it
        let _ = try await client.putManifest(repository: repository, reference: "latest", manifest: test_manifest)
        let firstTag = try await client.getTags(repository: repository).tags.sorted()
        #expect(firstTag == ["latest"])

        // After setting another tag, the original tag should still exist
        let _ = try await client.putManifest(
            repository: repository,
            reference: "additional_tag",
            manifest: test_manifest
        )
        let secondTag = try await client.getTags(repository: repository)
        #expect(secondTag.tags.sorted() == ["additional_tag", "latest"].sorted())
    }

    @Test func testGetNonexistentBlob() async throws {
        let repository = "testgetnonexistentblob"

        do {
            let _ = try await client.getBlob(
                repository: repository,
                digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            )
            Issue.record("should have thrown")
        } catch {}
    }

    @Test func testCheckNonexistentBlob() async throws {
        let repository = "testchecknonexistentblob"

        let exists = try await client.blobExists(
            repository: repository,
            digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
        #expect(!exists)
    }

    @Test func testPutAndGetBlob() async throws {
        let repository = "testputandgetblob"  // repository name must be lowercase

        let blob_data = "test".data(using: .utf8)!

        let descriptor = try await client.putBlob(repository: repository, data: blob_data)
        #expect(descriptor.digest == "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")

        let exists = try await client.blobExists(repository: repository, digest: descriptor.digest)
        #expect(exists)

        let blob = try await client.getBlob(repository: repository, digest: descriptor.digest)
        #expect(blob == blob_data)
    }

    @Test func testPutAndGetTaggedManifest() async throws {
        let repository = "testputandgettaggedmanifest"  // repository name must be lowercase

        // registry:2 does not validate the contents of the config or image blobs
        // so a smoke test can use simple data.   Other registries are not so forgiving.
        let config_data = "configuration".data(using: .utf8)!
        let config_descriptor = try await client.putBlob(
            repository: repository,
            mediaType: "application/vnd.docker.container.image.v1+json",
            data: config_data
        )

        let image_data = "image_layer".data(using: .utf8)!
        let image_descriptor = try await client.putBlob(
            repository: repository,
            mediaType: "application/vnd.docker.image.rootfs.diff.tar.gzip",
            data: image_data
        )

        let test_manifest = ImageManifest(
            schemaVersion: 2,
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            config: config_descriptor,
            layers: [image_descriptor]
        )

        let _ = try await client.putManifest(repository: repository, reference: "latest", manifest: test_manifest)

        let manifest = try await client.getManifest(repository: repository, reference: "latest")
        #expect(manifest.schemaVersion == 2)
        #expect(manifest.config.mediaType == "application/vnd.docker.container.image.v1+json")
        #expect(manifest.layers.count == 1)
        #expect(manifest.layers[0].mediaType == "application/vnd.docker.image.rootfs.diff.tar.gzip")
    }

    @Test func testPutAndGetAnonymousManifest() async throws {
        let repository = "testputandgetanonymousmanifest"  // repository name must be lowercase

        // registry:2 does not validate the contents of the config or image blobs
        // so a smoke test can use simple data.   Other registries are not so forgiving.
        let config_data = "configuration".data(using: .utf8)!
        let config_descriptor = try await client.putBlob(
            repository: repository,
            mediaType: "application/vnd.docker.container.image.v1+json",
            data: config_data
        )

        let image_data = "image_layer".data(using: .utf8)!
        let image_descriptor = try await client.putBlob(
            repository: repository,
            mediaType: "application/vnd.docker.image.rootfs.diff.tar.gzip",
            data: image_data
        )

        let test_manifest = ImageManifest(
            schemaVersion: 2,
            mediaType: "application/vnd.oci.image.manifest.v1+json",
            config: config_descriptor,
            layers: [image_descriptor]
        )

        let _ = try await client.putManifest(
            repository: repository,
            reference: test_manifest.digest,
            manifest: test_manifest
        )

        let manifest = try await client.getManifest(repository: repository, reference: test_manifest.digest)
        #expect(manifest.schemaVersion == 2)
        #expect(manifest.config.mediaType == "application/vnd.docker.container.image.v1+json")
        #expect(manifest.layers.count == 1)
        #expect(manifest.layers[0].mediaType == "application/vnd.docker.image.rootfs.diff.tar.gzip")
    }

    @Test func testPutAndGetImageConfiguration() async throws {
        let repository = "testputandgetimageconfiguration"  // repository name must be lowercase

        let configuration = ImageConfiguration(
            created: "1996-12-19T16:39:57-08:00",
            author: "test",
            architecture: "x86_64",
            os: "Linux",
            rootfs: .init(_type: "layers", diff_ids: ["abc123", "def456"]),
            history: [.init(created: "1996-12-19T16:39:57-08:00", author: "test", created_by: "smoketest")]
        )
        let config_descriptor = try await client.putImageConfiguration(
            repository: repository,
            configuration: configuration
        )

        let downloaded = try await client.getImageConfiguration(
            repository: repository,
            digest: config_descriptor.digest
        )

        #expect(configuration == downloaded)
    }
}
