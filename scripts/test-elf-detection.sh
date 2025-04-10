#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftContainerPlugin open source project
##
## Copyright (c) 2025 Apple Inc. and the SwiftContainerPlugin project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

#
# This script assumes that the Static Linux SDK has already been installed
#

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

set -euo pipefail

RUNTIME=${RUNTIME-"docker"}

#
# Create a test package
#
PKGPATH=$(mktemp -d)
swift package --package-path "$PKGPATH" init --type executable --name hello

cleanup() {
  log "Deleting temporary package $PKGPATH"
  rm -rf "$PKGPATH"
}
trap cleanup EXIT

#
# Build and package an x86_64 binary
#
swift build --package-path "$PKGPATH" --swift-sdk x86_64-swift-linux-musl
FILETYPE=$(file "$PKGPATH/.build/x86_64-swift-linux-musl/debug/hello")
log "Executable type: $FILETYPE"

IMGREF=$(swift run containertool --repository localhost:5000/elf_test "$PKGPATH/.build/x86_64-swift-linux-musl/debug/hello" --from scratch)
$RUNTIME pull "$IMGREF"
IMGARCH=$($RUNTIME inspect "$IMGREF" --format "{{.Architecture}}")
if [ "$IMGARCH" = "amd64" ] ; then
  log "x86_64 detection: PASSED"
else
  fatal "x86_64 detection: FAILED - image architecture was $IMGARCH; expected amd64"
fi

#
# Build and package an aarch64 binary
#
swift build --package-path "$PKGPATH" --swift-sdk aarch64-swift-linux-musl
FILETYPE=$(file "$PKGPATH/.build/x86_64-swift-linux-musl/debug/hello")
log "Executable type: $FILETYPE"

IMGREF=$(swift run containertool --repository localhost:5000/elf_test "$PKGPATH/.build/aarch64-swift-linux-musl/debug/hello" --from scratch)
$RUNTIME pull "$IMGREF"
IMGARCH=$($RUNTIME inspect "$IMGREF" --format "{{.Architecture}}")
if [ "$IMGARCH" = "arm64" ] ; then
  log "aarch64 detection: PASSED"
else
  fatal "aarch64 detection: FAILED - image architecture was $IMGARCH; expected arm64"
fi
