echo "Building.."
# ldc2 -mtriple=wasm32-unknown-unknown-wasm test.d -L-allow-undefined
cd dasm
dub build -c game-wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm -f
cd ..
