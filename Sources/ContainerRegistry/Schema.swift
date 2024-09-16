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

/// A registry response listing the tags defined in a repository.
public struct Tags: Codable, Hashable, Sendable {
    /// The repository namespace
    public var name: String
    /// The tags defined in this repository
    public var tags: [String]

    /// Creates a new `Tags`.
    /// - Parameters:
    ///   - name: The repository namespace.
    ///   - tags: The tags defined in this repository.
    public init(name: String, tags: [String]) {
        self.name = name
        self.tags = tags
    }
}

/// An empty JSON object
///
/// Some structures are directly serialized from the Go type `map[string]struct{}`, which is used to represent a set of strings.   In JSON these become objects where the keys are mapped to empty objects.   This struct represents those empty objects.
public struct EmptyObject: Codable, Hashable, Sendable {}

/// `ImageConfiguration` defines the contents of an image and how to run it.
///
/// The contents of `ImageConfiguration` include:
/// * metadata, such as when the image was created and by whom
/// * an ordered list of layers which make up the image
/// * the environment settings and parameters to pass to the image entrypoint at runtime
public struct ImageConfiguration: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/config.md

    /// The date and time when the image was created, in RFC 3339 format.
    public var created: String?

    /// The image's maintainer.
    public var author: String?

    /// The CPU architecture required to run the image.   Uses the same values as Go's `GOARCH` variable e.g. `amd64`, `arm64`.
    public var architecture: String

    /// The operating system required to run the image.   Uses the same values as Go's `GOOS` variable e.g. `linux`.
    public var os: String

    /// Parameters to pass to the entrypoint when the image is run.
    public var config: ImageConfigurationConfig?

    /// An ordered list of the filesystem layers which make up the image.
    public var rootfs: ImageConfigurationRootFS

    /// Metadata about each layer in the image, uppermost layer first.
    public var history: [ImageConfigurationHistory]?

    /// Creates a new `ImageConfiguration`.
    /// - Parameters:
    ///   - created: The date and time when the image was created, in RFC 3339 format.
    ///   - author: The image's maintainer.
    ///   - architecture: The CPU architecture required to run the image.   Uses the same values as Go's `GOARCH` variable e.g. `amd64`, `arm64`.
    ///   - os: The operating system required to run the image.   Uses the same values as Go's `GOOS` variable e.g. `linux`.
    ///   - config: Parameters to pass to the entrypoint when the image is run.
    ///   - rootfs: An ordered list of the filesystem layers which make up the image.
    ///   - history: Metadata about each layer in the image, uppermost layer first.
    public init(
        created: String? = nil,
        author: String? = nil,
        architecture: String,
        os: String,
        config: ImageConfigurationConfig? = nil,
        rootfs: ImageConfigurationRootFS,
        history: [ImageConfigurationHistory]? = nil
    ) {
        self.created = created
        self.author = author
        self.architecture = architecture
        self.os = os
        self.config = config
        self.rootfs = rootfs
        self.history = history
    }
}

/// `ImageConfigurationConfig` defines the image's runtime configuration.
///
/// The contents of `ImageConfigurationConfig` include:
///  * the entrypoint, or process to start when the image is run
///  * the environment in which the entrypoint should run e.g. user ID, working directory, environment variables and command-line parameters
///  * attached volumes and exposed network ports
public struct ImageConfigurationConfig: Codable, Hashable, Sendable {
    /// The user name or ID under which the entrypoint process should be run.
    public var User: String?

    /// Network ports to expose at runtime.   Ports are specified as "port/protocol" strings e.g. "80/tcp", "udp/53".   If the protocol is not given, "tcp" is assumed.
    public var ExposedPorts: [String: EmptyObject]?

    /// Default environment variables for the entrypoint process, formatted as "NAME=VALUE" strings e.g. "LOGLEVEL=INFO".
    public var Env: [String]?

    /// Default command to execute when the container is started.
    public var Entrypoint: [String]?

    /// Default arguments to pass to the entrypoint process.
    public var Cmd: [String]?

    /// Volumes to mount in the container.
    public var Volumes: [String: EmptyObject]?

    /// Default working directory for the entrypoint process.
    public var WorkingDir: String?

    /// Arbitrary labels to be applied to the running container.
    public var Labels: Annotations?

    /// Unix signal which should be sent to cause the entrypoint process to exit e.g. SIGKILL or SIGRTMIN+3.
    public var StopSignal: String?

    /// Creates a new `ImageConfigurationConfig`
    /// - Parameters:
    ///   - User: The user name or ID under which the entrypoint process should be run.
    ///   - ExposedPorts: Network ports to expose at runtime.   Ports are specified as "port/protocol" strings e.g. "80/tcp", "udp/53".   If the protocol is not given, "tcp" is assumed.
    ///   - Env: Default environment variables for the entrypoint process, formatted as "NAME=VALUE" strings e.g. "LOGLEVEL=INFO".
    ///   - Entrypoint: Default command to execute when the container is started.
    ///   - Cmd: Default arguments to pass to the entrypoint process.
    ///   - Volumes:  A set of directories describing where the process is likely write data specific to a container instance.
    ///   - WorkingDir: Default working directory for the entrypoint process.
    ///   - Labels: Arbitrary labels to be applied to the running container.
    ///   - StopSignal: Unix signal which should be sent to cause the entrypoint process to exit e.g. SIGKILL.
    public init(
        User: String? = nil,
        ExposedPorts: [String: EmptyObject]? = nil,
        Env: [String]? = nil,
        Entrypoint: [String]? = nil,
        Cmd: [String]? = nil,
        Volumes: [String: EmptyObject]? = nil,
        WorkingDir: String? = nil,
        Labels: Annotations? = nil,
        StopSignal: String? = nil
    ) {
        self.User = User
        self.ExposedPorts = ExposedPorts
        self.Env = Env
        self.Cmd = Cmd
        self.Volumes = Volumes
        self.WorkingDir = WorkingDir
        self.Labels = Labels
        self.StopSignal = StopSignal
    }
}

/// `ImageConfigurationRootFS` refers to the layers which make up the image.
public struct ImageConfigurationRootFS: Codable, Hashable, Sendable {
    /// The image type.    Currently the only acceptable value is "layers".
    public var _type: String

    /// Ordered list of layers which which make up the image, with the topmost layer first.   These are the hashes of the unpacked layers, not the hashes of the blobs which contain them.
    public var diff_ids: [String]

    /// Creates a new `ImageConfigurationRootFS`
    /// - Parameters:
    ///   - _type: Must be "layers".
    ///   - diff_ids: Ordered list of layers which which make up the image, with the topmost layer first.
    public init(_type: String = "layers", diff_ids: [String]) {
        self._type = _type
        self.diff_ids = diff_ids
    }

    public enum CodingKeys: String, CodingKey {
        case _type = "type"
        case diff_ids
    }
}

/// Describes the history of each layer.
public struct ImageConfigurationHistory: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/config.md

    /// The date and time when the image was created, in RFC 3339 format.
    public var created: String?

    /// The layer's maintainer.
    public var author: String?

    /// The command which created the layer.
    public var created_by: String?

    /// An arbitrary comment for the layer.
    public var comment: String?

    /// If `true`, the layer does not cause any filesystem changes.
    public var empty_layer: Bool?

    /// Creates a new `ImageConfigurationHistory`
    /// - Parameters:
    ///   - created: The date and time when the image was created, in RFC 3339 format.
    ///   - author: The layer's maintainer.
    ///   - created_by: The command which created the layer.
    ///   - comment: An arbitrary comment for the layer.
    ///   - empty_layer: If `true`, the layer does not cause any filesystem changes.
    public init(
        created: String? = nil,
        author: String? = nil,
        created_by: String? = nil,
        comment: String? = nil,
        empty_layer: Bool? = nil
    ) {
        self.created = created
        self.author = author
        self.created_by = created_by
        self.comment = comment
        self.empty_layer = empty_layer
    }
}

/// `ImageManifest` defines an image which runs on a specific architecture and operating system.
/// Multi-platform images are created by grouping several `ImageManifest`s for different operating
/// systems and architectures together under an `ImageIndex`.
public struct ImageManifest: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/config.md

    /// Schema version, must be `2`.
    public var schemaVersion: Int

    /// The MIME type of this object.
    public var mediaType: String?

    /// A `ContentDescriptor` pointing to the blob containing the `ImageConfiguration` for this image.
    public var config: ContentDescriptor

    /// An ordered array of `ContentDescriptors` pointing to the blobs which contain the layers of the image.    The first entry in the array must be the base layer.
    public var layers: [ContentDescriptor]

    /// Arbitrary labels to be applied to the container image.
    public var annotations: Annotations?

    /// Creates a new `ImageManifest`
    /// - Parameters:
    ///   - schemaVersion: Must be `2`
    ///   - mediaType: The MIME type describing this object.
    ///   - config: A `ContentDescriptor` pointing to the blob containing the `ImageConfiguration` for this image.
    ///   - layers: An ordered array of `ContentDescriptors` pointing to the blobs which contain the layers of the image.    The first entry in the array must be the base layer.
    ///   - annotations: Arbitrary labels to be applied to the container image.
    public init(
        schemaVersion: Int = 2,
        mediaType: String? = nil,
        config: ContentDescriptor,
        layers: [ContentDescriptor],
        annotations: Annotations? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mediaType = mediaType
        self.config = config
        self.layers = layers
        self.annotations = annotations
    }
}

/// `ImageIndex` defines a multi-platform image which can run on several underlying operating systems
/// or CPU architectures.    It points to a set of `ImageManifest` objects, each of which defines the
/// image for a specific operating system and architecture
public struct ImageIndex: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/config.md

    /// Schema version, must be `2`.
    public var schemaVersion: Int

    /// The MIME type of this object.
    public var mediaType: String?

    /// An array of `ContentDescriptors` pointing to the OS- and architecture-specific `ImageManifest` objects.   May be empty.
    public var manifests: [ContentDescriptor]

    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/annotations.md
    /// Arbitrary labels to be applied to the container image.
    public var annotations: Annotations?

    /// Creates a new `ImageIndex`
    /// - Parameters:
    ///   - schemaVersion: Schema version, must be `2`.
    ///   - mediaType: The MIME type of this object.
    ///   - manifests: An array of `ContentDescriptors` pointing to the OS- and architecture-specific `ImageManifest` objects.   May be empty.
    ///   - annotations: Arbitrary labels to be applied to the container image.
    public init(
        schemaVersion: Int = 2,
        mediaType: String? = nil,
        manifests: [ContentDescriptor],
        annotations: Annotations? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mediaType = mediaType
        self.manifests = manifests
        self.annotations = annotations
    }
}

/// `Annotations` are arbitrary key-value metadata which can be applied to some objects.   Values may be the empty string.
public typealias Annotations = [String: String]

/// A `ContentDescriptor` is a reference to an object stored in the registry.    `ContentDescriptor`s are the links between objects in the image graph.
public struct ContentDescriptor: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/image-spec/blob/v1.0.1/descriptor.md

    /// The MIME type of the stored object.
    public var mediaType: String

    /// The digest of the stored object.
    public var digest: String

    /// The size of the raw stored object, in bytes.
    public var size: Int64

    /// Alternative URLs from which the stored object can be downloaded.
    public var urls: [String]?

    /// If the descriptor is part of an `ImageIndex` and points to an `ImageManifest`, this field holds the runtime requirements of the image.   Can be used by the runtime to decide which platform-specific `ImageManifest` to download.
    public var platform: Platform?

    /// Arbitrary labels for the descriptor.
    public var annotations: Annotations?

    /// Creates a new `ContentDescriptor`
    /// - Parameters:
    ///   - mediaType: The MIME type of the stored object.
    ///   - digest: The digest of the stored object.
    ///   - size: The size of the raw stored object, in bytes.
    ///   - urls: Alternative URLs from which the stored object can be downloaded.
    ///   - platform: Runtime requirements of the image - only present if the descriptor is part of an `ImageIndex`.
    ///   - annotations: Arbitrary labels for the descriptor.
    public init(
        mediaType: String,
        digest: String,
        size: Int64,
        urls: [String]? = nil,
        platform: Platform? = nil,
        annotations: Annotations? = nil
    ) {
        self.mediaType = mediaType
        self.digest = digest
        self.size = size
        self.urls = urls
        self.platform = platform
        self.annotations = annotations
    }
}

/// `Platform` describes the minimum runtime requirements of the image.
public struct Platform: Codable, Hashable, Sendable {
    // https://github.com/opencontainers/image-spec/blob/v1.0.1/image-index.md

    /// The CPU architecture required to run the image.   Uses the same values as Go's `GOARCH` variable e.g. `amd64`, `arm64`.
    public var architecture: String

    /// The operating system required to run the image.   Uses the same values as Go's `GOOS` variable e.g. `linux`..
    public var os: String

    /// The specific version of the operating system required.   Values are implementation-defined.
    public var osVersion: String?

    /// A list of required operating system features.   Values are implementation-defined.
    public var osFeatures: [String]?

    /// A specific CPU architecture variant.
    public var variant: String?

    /// Reserved.
    public var features: [String]?

    /// Creates a new `Platform`
    /// - Parameters:
    ///   - architecture: The CPU architecture required to run the image.
    ///   - os: The operating system required to run the image.
    ///   - osVersion: The specific version of the operating system required.
    ///   - osFeatures: A list of required operating system features.
    ///   - variant: A specific CPU architecture variant.
    ///   - features: Reserved.
    public init(
        architecture: String,
        os: String,
        osVersion: String? = nil,
        osFeatures: [String]? = nil,
        variant: String? = nil,
        features: [String]? = nil
    ) {
        self.architecture = architecture
        self.os = os
        self.osVersion = osVersion
        self.osFeatures = osFeatures
        self.variant = variant
        self.features = features
    }

    public enum CodingKeys: String, CodingKey {
        case architecture
        case os
        case osVersion = "os.version"
        case osFeatures = "os.features"
        case variant
        case features
    }
}

/// DistributionErrors represents a list of errors returned by registry
public struct DistributionErrors: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#error-codes

    /// A list of API errors
    public var errors: [DistributionError]

    /// Creates a new `DistributionErrors`
    /// - Parameter errors: A list of API errors
    public init(errors: [DistributionError]) { self.errors = errors }
}

/// An individual error returned by the registry
public struct DistributionError: Codable, Hashable, Sendable {
    // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#error-codes

    /// Unique error identifier
    public var code: DistributionErrorCode
    /// Human-readable description of the error.
    public var message: String?

    // DistributionError may contain a third optional field `detail`, an opaque field containing arbitrary JSON data about the error.
    // JSONEncoder requires all fields to be fully defined, so this field is currently not supported.
    // public var detail: String?

    /// Creates a new `DistributionError`
    /// - Parameters:
    ///   - code: Unique error identifier.
    ///   - message: Human-readable description of the error.
    public init(code: DistributionErrorCode, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

/// Error codes returned by the registry.
/// Values must be all uppercase.
public enum DistributionErrorCode: String, Codable, Sendable, Hashable {
    // See https://github.com/opencontainers/distribution-spec/blob/main/spec.md#error-codes
    case unsupportedAPI = "UNSUPPORTED_API"
    case blobUnknown = "BLOB_UNKNOWN"
    case blobUploadInvalid = "BLOB_UPLOAD_INVALID"
    case blobUploadUnknown = "BLOB_UPLOAD_UNKNOWN"
    case digestInvalid = "DIGEST_INVALID"
    case manifestBlobUnknown = "MANIFEST_BLOB_UNKNOWN"  // also returned for index
    case manifestInvalid = "MANIFEST_INVALID"
    case manifestUnknown = "MANIFEST_UNKNOWN"
    case nameInvalid = "NAME_INVALID"
    case nameUnknown = "NAME_UNKNOWN"
    case sizeInvalid = "SIZE_INVALID"
    case unauthorized = "UNAUTHORIZED"
    case denied = "DENIED"
    case unsupported = "UNSUPPORTED"
    case tooManyRequests = "TOOMANYREQUESTS"
}
