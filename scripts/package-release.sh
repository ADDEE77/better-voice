#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
cd "$script_dir/.."

if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 "BetterVoice releases are currently built for Apple Silicon (arm64)."
  exit 1
fi

signing_identity=${BETTERVOICE_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*) \([0-9A-F]*\) \"Apple Development:.*/\1/p' | head -n 1)}
if [[ -z "$signing_identity" ]]; then
  print -u2 "An Apple Development signing identity is required for this experimental release."
  exit 1
fi

BETTERVOICE_SIGNING_IDENTITY="$signing_identity" BETTERVOICE_SKIP_OPEN=1 "$script_dir/build-app.sh"

signature_details=$(codesign -dv --verbose=2 ".build/BetterVoice.app" 2>&1)
if [[ "$signature_details" != *"Authority=Apple Development:"* ]]; then
  print -u2 "The release app is not signed with an Apple Development identity."
  exit 1
fi

rm -rf dist
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent ".build/BetterVoice.app" "dist/BetterVoice-macos-arm64.zip"
(cd dist && shasum -a 256 "BetterVoice-macos-arm64.zip" > "SHA256SUMS.txt")
codesign --verify --deep --strict ".build/BetterVoice.app"

print "Created dist/BetterVoice-macos-arm64.zip"
cat "dist/SHA256SUMS.txt"
