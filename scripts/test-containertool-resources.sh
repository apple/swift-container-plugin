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

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

set -euo pipefail

RUNTIME=${RUNTIME-"docker"}
PKGPATH=$(mktemp -d)

#
# Package an example payload with resources.  This test only checks
# that the correct files are in the container image and does not run
# it, so the payload does not need to be an executable.
#
touch "$PKGPATH/hello"
mkdir -p "$PKGPATH/resourcedir"
touch "$PKGPATH/resourcedir/resource1.txt" "$PKGPATH/resourcedir/resource2.txt" "$PKGPATH/resourcedir/resource3.txt"
touch "$PKGPATH/resourcefile.dat"
swift run containertool \
   "$PKGPATH/hello" \
   --repository localhost:5000/resource_test \
   --from scratch \
   --resources "$PKGPATH/resourcedir" \
   --resources "$PKGPATH/resourcefile.dat"

$RUNTIME rm -f resource-test
$RUNTIME create --pull always --name resource-test localhost:5000/resource_test:latest

cleanup() {
  log "Deleting temporary package $PKGPATH"
  rm -rf "$PKGPATH"

  log "Deleting resource-test container"
  $RUNTIME rm -f resource-test
}
trap cleanup EXIT


for resource in \
   /hello \
   /resourcedir/resource1.txt \
   /resourcedir/resource2.txt \
   /resourcedir/resource3.txt \
   /resourcefile.dat
do
   # This will return a non-zero exit code if the file does not exist
   if $RUNTIME cp resource-test:$resource - > /dev/null ; then
     log "$resource: OK"
   else
     fatal "$resource: FAILED"
   fi
done

