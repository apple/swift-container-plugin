#!/usr/bin/env bash

# Test that error output streamed from containertool is printed correctly by the plugin. 

set -exo pipefail

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

swift package --package-path "$PKGPATH" init --type executable --name hello
cat >> "$PKGPATH/Package.swift" <<EOF
package.dependencies += [
    .package(path: "$PWD"),
]
EOF

# Run the plugin, forgetting a mandatory argument.   Verify that the output is not corrupted.
# The `swift package` command will return a nonzero exit code.   This is expected, so disable pipefail.
set +o pipefail
swift package --package-path "$PKGPATH" --allow-network-connections all build-container-image 2>&1 | tee "$PKGPATH/output"
set -o pipefail

grep -F -x -e "error: Missing expected argument '--repository <repository>'" \
           -e "error: Help:  --repository <repository>  Repository path" \
           -e "error: Usage: containertool [<options>] --repository <repository> <executable>" \
           -e "error:   See 'containertool --help' for more information." "$PKGPATH/output"

echo Plugin error output: PASSED

