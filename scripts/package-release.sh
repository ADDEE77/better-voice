#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
cd "$script_dir/.."

BETTERVOICE_SKIP_OPEN=1 "$script_dir/build-app.sh"

rm -rf dist
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent ".build/BetterVoice.app" "dist/BetterVoice-macos-arm64.zip"
shasum -a 256 "dist/BetterVoice-macos-arm64.zip" > "dist/SHA256SUMS.txt"
codesign --verify --deep --strict ".build/BetterVoice.app"

print "Created dist/BetterVoice-macos-arm64.zip"
cat "dist/SHA256SUMS.txt"
