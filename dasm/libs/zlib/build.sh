#!/usr/bin/env bash

PATH_ZLIB=

clang -c -emit-llvm --target=wasm32 -nostdlib -nostdinc -DZ_SOLO -Izlib/  zlib/adler32.c zlib/crc32.c zlib/deflate.c  zlib/infback.c  zlib/inffast.c  zlib/inflate.c  zlib/inftrees.c  zlib/trees.c  zlib/zutil.c

llvm-link -o zlib.bc adler32.bc crc32.bc deflate.bc  infback.bc  inffast.bc  inflate.bc  inftrees.bc  trees.bc  zutil.bc

llvm-ar rv zlib.a zlib.bc
