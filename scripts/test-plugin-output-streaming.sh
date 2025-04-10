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

# Test that error output streamed from containertool is printed correctly by the plugin. 

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Work in a temporary directory, deleted after the test finishes
PKGPATH=$(mktemp -d)
cleanup() {
  log "Deleting temporary package $PKGPATH"
  rm -rf "$PKGPATH"
}
trap cleanup EXIT

# Create a test project which depends on this checkout of the plugin repository
REPO_ROOT=$(git rev-parse --show-toplevel)
swift package --package-path "$PKGPATH" init --type executable --name hello
cat >> "$PKGPATH/Package.swift" <<EOF
package.dependencies += [
    .package(path: "$REPO_ROOT"),
]
EOF
cat "$PKGPATH/Package.swift"

# Run the plugin, forgetting a mandatory argument.   Verify that the output is not corrupted.
# The `swift package` command will return a nonzero exit code.   This is expected, so disable pipefail.
set +o pipefail
swift package --package-path "$PKGPATH" --allow-network-connections all build-container-image 2>&1 | tee "$PKGPATH/output"
set -o pipefail

# This checks that the output lines are not broken, but not that they appear in the correct order
grep -F -x -e "error: Missing expected argument '--repository <repository>'" \
           -e "error: Help:  --repository <repository>  Repository path" \
           -e "error: Usage: containertool [<options>] --repository <repository> <executable>" \
           -e "error:   See 'containertool --help' for more information." "$PKGPATH/output"

log Plugin error output: PASSED

