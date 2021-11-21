#!/usr/bin/env bash

echo "Building.."
cd dasm/game
dub build -c game-wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm -b release -f
cd ..
