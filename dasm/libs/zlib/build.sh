#!/usr/bin/env bash

PATH_ZLIB=/home/ryuukk/tmp/zlib

mkdir -p build/
cd build/

clang -c -emit-llvm --target=wasm32 -nostdlib -nostdinc -DZ_SOLO \
    -I$PATH_ZLIB          \
    $PATH_ZLIB/adler32.c  \
    $PATH_ZLIB/crc32.c    \
    $PATH_ZLIB/deflate.c  \
    $PATH_ZLIB/infback.c  \
    $PATH_ZLIB/inffast.c  \
    $PATH_ZLIB/inflate.c  \
    $PATH_ZLIB/inftrees.c \
    $PATH_ZLIB/trees.c    \
    $PATH_ZLIB/zutil.c    \

llvm-link -o zlib.bc adler32.bc crc32.bc deflate.bc  infback.bc  inffast.bc  inflate.bc  inftrees.bc  trees.bc  zutil.bc

llvm-ar rv zlib.a zlib.bc

cd ../
