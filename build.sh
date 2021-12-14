#!/usr/bin/env bash

BUILD=true
OPT=true
OUTPUT=bin/game.wasm # for opt build

echo "Building for WASM in '$BUILD' mode opt: '$OPT' os: '$OSTYPE'" 
cd dasm/game

dub build -c wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm -b $BUILD

cd ../..

if [[ $OPT == true ]]; then
    echo "Optimizing wasm file for size.."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wasm-opt -Oz -o bin/game.wasm bin/game.wasm
    elif [[ "$OSTYPE" == "win32" ]]; then
        C:/emsdk/upstream/bin/wasm-opt -Oz -o $OUTPUT bin/game.wasm
    elif [[ "$OSTYPE" == "msys" ]]; then
        # TODO: use package manager's path
        C:/emsdk/upstream/bin/wasm-opt -Oz -o $OUTPUT bin/game.wasm
    fi
fi