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

@testable import ContainerRegistry
import Testing

struct ReferenceTestCase: Sendable {
    var reference: String
    var expected: ImageReference
}

struct ReferenceTests {
    static let tests = [
        // A reference which does not contain a '/' is always interpreted as a repository name
        // in the default registry.
        ReferenceTestCase(
            reference: "localhost",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("localhost"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example.com",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("example.com"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example:1234",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("example"),
                reference: ImageReference.Tag("1234")
            )
        ),

        // If a reference contains a '/' *and* the component before the '/' looks like a
        // hostname, the part before the '/' is interpreted as a registry and the part after
        // the '/' is used as a repository.
        //
        // In general a hostname must have at least two dot-separated components.
        // "localhost" is a special case.
        ReferenceTestCase(
            reference: "localhost/foo",
            expected: try! ImageReference(
                registry: "localhost",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "localhost:1234/foo",
            expected: try! ImageReference(
                registry: "localhost:1234",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example.com/foo",
            expected: try! ImageReference(
                registry: "example.com",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example.com:1234/foo",
            expected: try! ImageReference(
                registry: "example.com:1234",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example.com:1234/foo:bar",
            expected: try! ImageReference(
                registry: "example.com:1234",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("bar")
            )
        ),

        // If the part before the '/' does not look like a hostname, the whole reference
        // is interpreted as a repository name in the default registry.
        ReferenceTestCase(
            reference: "local/foo",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("local/foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example/foo",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("example/foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
        ReferenceTestCase(
            reference: "example/foo:1234",
            expected: try! ImageReference(
                registry: "default",
                repository: ImageReference.Repository("example/foo"),
                reference: ImageReference.Tag("1234")
            )
        ),

        // Distribution spec tests
        ReferenceTestCase(
            reference: "example.com/foo@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            expected: try! ImageReference(
                registry: "example.com",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Digest(
                    "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                )
            )
        ),

        ReferenceTestCase(
            reference:
                "example.com/foo@sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            expected: try! ImageReference(
                registry: "example.com",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Digest(
                    "sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                )
            )
        ),

        ReferenceTestCase(
            reference: "foo:1234/bar:1234",
            expected: try! ImageReference(
                registry: "foo:1234",
                repository: ImageReference.Repository("bar"),
                reference: ImageReference.Tag("1234")
            )
        ),

        // Capitals are not allowed in repository names but are allowed in hostnames (matching podman's behaviour)
        ReferenceTestCase(
            reference: "EXAMPLE.COM/foo:latest",
            expected: try! ImageReference(
                registry: "EXAMPLE.COM",
                repository: ImageReference.Repository("foo"),
                reference: ImageReference.Tag("latest")
            )
        ),
    ]

    @Test(arguments: tests)
    func testValidReferences(test: ReferenceTestCase) throws {
        let parsed = try! ImageReference(fromString: test.reference, defaultRegistry: "default")
        #expect(
            parsed == test.expected,
            "\(String(reflecting: parsed)) is not equal to \(String(reflecting: test.expected))"
        )
    }

    @Test
    func testInvalidReferences() throws {
        #expect(throws: ImageReference.Repository.ValidationError.emptyString) {
            try ImageReference(fromString: "", defaultRegistry: "default")
        }

        #expect(throws: ImageReference.Repository.ValidationError.emptyString) {
            try ImageReference(fromString: "example.com/")
        }

        #expect(throws: ImageReference.Repository.ValidationError.containsUppercaseLetters("helloWorld")) {
            try ImageReference(fromString: "helloWorld", defaultRegistry: "default")
        }

        #expect(throws: ImageReference.Repository.ValidationError.containsUppercaseLetters("helloWorld")) {
            try ImageReference(fromString: "localhost:5555/helloWorld")
        }

        #expect(throws: ImageReference.Repository.ValidationError.invalidReferenceFormat("hello^world")) {
            try ImageReference(fromString: "localhost:5555/hello^world")
        }
    }

    @Test
    func testLibraryReferences() throws {
        // docker.io is a special case, as references such as "swift:slim" with no registry component are translated to "docker.io/library/swift:slim"
        // Verified against the behaviour of the docker CLI client

        // Fully-qualified name splits as usual
        #expect(
            try! ImageReference(fromString: "docker.io/library/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "index.docker.io",
                    repository: ImageReference.Repository("library/swift"),
                    reference: ImageReference.Tag("slim")
                )
        )

        // A repository with no '/' part is assumed to be `library`
        #expect(
            try! ImageReference(fromString: "docker.io/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "index.docker.io",
                    repository: ImageReference.Repository("library/swift"),
                    reference: ImageReference.Tag("slim")
                )
        )

        // Parsing with 'docker.io' as default registry is the same as the fully qualified case
        #expect(
            try! ImageReference(fromString: "library/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "index.docker.io",
                    repository: ImageReference.Repository("library/swift"),
                    reference: ImageReference.Tag("slim")
                )
        )

        // Bare image name with no registry or repository is interpreted as being in docker.io/library when default is docker.io
        #expect(
            try! ImageReference(fromString: "swift:slim", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "index.docker.io",
                    repository: ImageReference.Repository("library/swift"),
                    reference: ImageReference.Tag("slim")
                )
        )

        // The minimum reference to a library image.   No tag implies `latest`
        #expect(
            try! ImageReference(fromString: "swift", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "index.docker.io",
                    repository: ImageReference.Repository("library/swift"),
                    reference: ImageReference.Tag("latest")
                )
        )

        // If the registry is not docker.io, the special case logic for `library` does not apply
        #expect(
            try! ImageReference(fromString: "localhost:5000/swift", defaultRegistry: "docker.io")
                == ImageReference(
                    registry: "localhost:5000",
                    repository: ImageReference.Repository("swift"),
                    reference: ImageReference.Tag("latest")
                )
        )

        #expect(
            try! ImageReference(fromString: "swift", defaultRegistry: "localhost:5000")
                == ImageReference(
                    registry: "localhost:5000",
                    repository: ImageReference.Repository("swift"),
                    reference: ImageReference.Tag("latest")
                )
        )
    }

    @Test
    func testScratchReferences() throws {
        // The unqualified "scratch" image is handled locally so should not be expanded.
        #expect(
            try! ImageReference(fromString: "scratch", defaultRegistry: "localhost:5000")
                == ImageReference(
                    registry: "",
                    repository: ImageReference.Repository("scratch"),
                    reference: ImageReference.Tag("latest")
                )
        )
    }

    @Test
    func testReferenceDescription() throws {
        #expect(
            "\(try! ImageReference(fromString: "swift", defaultRegistry: "localhost:5000"))"
                == "localhost:5000/swift:latest"
        )

        #expect(
            "\(try! ImageReference(fromString: "library/swift:slim", defaultRegistry: "docker.io"))"
                == "index.docker.io/library/swift:slim"
        )

        #expect(
            "\(try! ImageReference(fromString: "scratch", defaultRegistry: "localhost:5000"))" == "scratch:latest"
        )
    }
}

struct DigestTests {
    @Test(arguments: [
        (
            digest: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            algorithm: "sha256", value: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        ),
        (
            digest: "sha512:"
                + "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                + "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            algorithm: "sha512",
            value: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                + "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        ),
    ])
    func testParseValidDigest(digest: String, algorithm: String, value: String) throws {
        let parsed = try! ImageReference.Digest(digest)

        #expect("\(parsed.algorithm)" == algorithm)
        #expect(parsed.value == value)
        #expect("\(parsed)" == digest)
    }

    @Test(arguments: [
        "sha256:0123456789abcdef0123456789abcdef0123456789abcdef",  // short digest
        "foo:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",  // bad algorithm
        "sha256-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",  // bad separator
    ])
    func testParseInvalidDigest(digest: String) throws {
        #expect(throws: ImageReference.Digest.ValidationError.invalidReferenceFormat(digest)) {
            try ImageReference.Digest(digest)
        }
    }

    @Test
    func testDigestEquality() throws {
        let digest1 = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let digest2 = "sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
        let digest3 =
            "sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            + "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        #expect(try ImageReference.Digest(digest1) != ImageReference.Digest(digest2))
        #expect(try ImageReference.Digest(digest1) != ImageReference.Digest(digest3))

        // Same string, parsed twice, should yield the same digest
        let sha256left = try ImageReference.Digest(digest1)
        let sha256right = try ImageReference.Digest(digest1)
        #expect(sha256left == sha256right)

        let sha512left = try ImageReference.Digest(digest3)
        let sha512right = try ImageReference.Digest(digest3)
        #expect(sha512left == sha512right)
    }
}
