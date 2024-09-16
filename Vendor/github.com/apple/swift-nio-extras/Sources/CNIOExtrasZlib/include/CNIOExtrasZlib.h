//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#ifndef C_NIO_ZLIB_H
#define C_NIO_ZLIB_H

#include <zlib.h>

static inline int CNIOExtrasZlib_deflateInit2(z_streamp strm,
                                              int level,
                                              int method,
                                              int windowBits,
                                              int memLevel,
                                              int strategy) {
    return deflateInit2(strm, level, method, windowBits, memLevel, strategy);
}

static inline int CNIOExtrasZlib_inflateInit2(z_streamp strm, int windowBits) {
    return inflateInit2(strm, windowBits);
}

static inline Bytef *CNIOExtrasZlib_voidPtr_to_BytefPtr(void *in) {
    return (Bytef *)in;
}

#endif
