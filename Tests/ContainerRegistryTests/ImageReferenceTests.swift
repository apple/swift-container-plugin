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
    var expected: ImageReference?
}

struct ReferenceTests {
    static let tests = [
        // A reference which does not contain a '/' is always interpreted as a repository name
        // in the default registry.
        ReferenceTestCase(
            reference: "localhost",
            expected: ImageReference(registry: "default", repository: "localhost", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example.com",
            expected: ImageReference(registry: "default", repository: "example.com", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example:1234",
            expected: ImageReference(registry: "default", repository: "example", reference: "1234")
        ),

        // If a reference contains a '/' *and* the component before the '/' looks like a
        // hostname, the part before the '/' is interpreted as a registry and the part after
        // the '/' is used as a repository.
        //
        // In general a hostname must have at least two dot-separated components.
        // "localhost" is a special case.
        ReferenceTestCase(
            reference: "localhost/foo",
            expected: ImageReference(registry: "localhost", repository: "foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "localhost:1234/foo",
            expected: ImageReference(registry: "localhost:1234", repository: "foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example.com/foo",
            expected: ImageReference(registry: "example.com", repository: "foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example.com:1234/foo",
            expected: ImageReference(registry: "example.com:1234", repository: "foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example.com:1234/foo:bar",
            expected: ImageReference(registry: "example.com:1234", repository: "foo", reference: "bar")
        ),

        // If the part before the '/' does not look like a hostname, the whole reference
        // is interpreted as a repository name in the default registry.
        ReferenceTestCase(
            reference: "local/foo",
            expected: ImageReference(registry: "default", repository: "local/foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example/foo",
            expected: ImageReference(registry: "default", repository: "example/foo", reference: "latest")
        ),
        ReferenceTestCase(
            reference: "example/foo:1234",
            expected: ImageReference(registry: "default", repository: "example/foo", reference: "1234")
        ),

        // Distribution spec tests
        ReferenceTestCase(
            reference: "example.com/foo@sha256:0123456789abcdef01234567890abcdef",
            expected: ImageReference(
                registry: "example.com",
                repository: "foo",
                reference: "sha256:0123456789abcdef01234567890abcdef"
            )
        ),

        // This example goes against the distribution spec's regular expressions but matches observed client behaviour
        ReferenceTestCase(
            reference: "foo:1234/bar:1234",
            expected: ImageReference(registry: "foo:1234", repository: "bar", reference: "1234")
        ),
        ReferenceTestCase(
            reference: "localhost/foo:1234/bar:1234",
            expected: ImageReference(registry: "localhost", repository: "foo", reference: "1234/bar:1234")
        ),
    ]

    @Test(arguments: tests) func testReferences(test: ReferenceTestCase) throws {
        let parsed = try! ImageReference(fromString: test.reference, defaultRegistry: "default")
        #expect(
            parsed == test.expected,
            "\(String(reflecting: parsed)) is not equal to \(String(reflecting: test.expected))"
        )
    }

    @Test func testLibraryReferences() throws {
        // docker.io is a special case, as references such as "swift:slim" with no registry component are translated to "docker.io/library/swift:slim"
        // Verified against the behaviour of the docker CLI client

        // Fully-qualified name splits as usual
        #expect(
            try! ImageReference(fromString: "docker.io/library/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(registry: "index.docker.io", repository: "library/swift", reference: "slim")
        )

        // A repository with no '/' part is assumed to be `library`
        #expect(
            try! ImageReference(fromString: "docker.io/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(registry: "index.docker.io", repository: "library/swift", reference: "slim")
        )

        // Parsing with 'docker.io' as default registry is the same as the fully qualified case
        #expect(
            try! ImageReference(fromString: "library/swift:slim", defaultRegistry: "docker.io")
                == ImageReference(registry: "index.docker.io", repository: "library/swift", reference: "slim")
        )

        // Bare image name with no registry or repository is interpreted as being in docker.io/library when default is docker.io
        #expect(
            try! ImageReference(fromString: "swift:slim", defaultRegistry: "docker.io")
                == ImageReference(registry: "index.docker.io", repository: "library/swift", reference: "slim")
        )

        // The minimum reference to a library image.   No tag implies `latest`
        #expect(
            try! ImageReference(fromString: "swift", defaultRegistry: "docker.io")
                == ImageReference(registry: "index.docker.io", repository: "library/swift", reference: "latest")
        )

        // If the registry is not docker.io, the special case logic for `library` does not apply
        #expect(
            try! ImageReference(fromString: "localhost:5000/swift", defaultRegistry: "docker.io")
                == ImageReference(registry: "localhost:5000", repository: "swift", reference: "latest")
        )

        #expect(
            try! ImageReference(fromString: "swift", defaultRegistry: "localhost:5000")
                == ImageReference(registry: "localhost:5000", repository: "swift", reference: "latest")
        )
    }
}
