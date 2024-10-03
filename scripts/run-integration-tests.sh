#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftContainerPlugin open source project
##
## Copyright (c) 2024 Apple Inc. and the SwiftContainerPlugin project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##


log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

if [[ -n ${TOOLCHAINS+x} ]] ; then
    fatal "Please unset the TOOLCHAINS environment variable.   The OSS Swift toolchain cannot run these tests because it does not include XCTest.framework."
fi

set -euo pipefail

RUNTIME=${RUNTIME-"docker"}

# Start a registry on an ephemeral port
REGISTRY_ID=$($RUNTIME run -d --rm -p 127.0.0.1::5000 registry:2)
export REGISTRY_HOST="localhost"
REGISTRY_PORT=$($RUNTIME port "$REGISTRY_ID" 5000/tcp | sed -E 's/^.+:([[:digit:]]+)$/\1/')
export REGISTRY_PORT
log "Registry $REGISTRY_ID listening on $REGISTRY_HOST:$REGISTRY_PORT"

# Delete the registry after running the tests, regardless of the outcome
cleanup() {
  log "Deleting registry $REGISTRY_ID"
  $RUNTIME rm -f "$REGISTRY_ID"
}
trap cleanup EXIT

log "Running smoke tests"
swift test --filter 'SmokeTests'
