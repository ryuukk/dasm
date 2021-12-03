#!/usr/bin/env bash

echo "Building.."
cd dasm/game

# dub build -c wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm -b release
dub build -c wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm

cd ../..

# echo "Optimizing wasm file for size.."
# wasm-opt -Oz -o bin/game.wasm bin/game.wasm
