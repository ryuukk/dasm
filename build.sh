#!/usr/bin/env bash

echo "Building.."
cd dasm/game
dub build -c wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm
cd ..
