#!/usr/bin/env bash

set -ex -o pipefail

PKGPATH=$(mktemp -d)
swift package --package-path "$PKGPATH" init --type executable --name hello

# Build and package an x86_64 binary
swift build --package-path "$PKGPATH" --swift-sdk x86_64-swift-linux-musl
file "$PKGPATH/.build/x86_64-swift-linux-musl/debug/hello"
IMGREF=$(swift run containertool --repository localhost:5000/elf_test "$PKGPATH/.build/x86_64-swift-linux-musl/debug/hello" --from scratch)
docker pull "$IMGREF"
docker inspect "$IMGREF" --format "{{.Architecture}}" | grep amd64
echo x86_64 detection: PASSED

# Build and package an aarch64 binary
swift build --package-path "$PKGPATH" --swift-sdk aarch64-swift-linux-musl
file "$PKGPATH/.build/aarch64-swift-linux-musl/debug/hello"
IMGREF=$(swift run containertool --repository localhost:5000/elf_test "$PKGPATH/.build/aarch64-swift-linux-musl/debug/hello" --from scratch)
docker pull "$IMGREF"
docker inspect "$IMGREF" --format "{{.Architecture}}" | grep arm64

echo aarch64 detection: PASSED
