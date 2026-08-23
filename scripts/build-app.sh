#!/bin/zsh
set -euo pipefail

swift build -c release
app_dir=".build/BetterVoice.app"
rm -rf ".build/BetterVoice.app"
mkdir -p "$app_dir/Contents/MacOS"
cp ".build/release/BetterVoice" "$app_dir/Contents/MacOS/BetterVoice"
cp "Info.plist" "$app_dir/Contents/Info.plist"
signing_identity=${BETTERVOICE_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | awk 'NR == 1 { print $2 }')}
if [[ -z "$signing_identity" ]]; then
  print -u2 "BetterVoice needs a stable code-signing identity so macOS permissions survive rebuilds."
  exit 1
fi
codesign --force --deep --sign "$signing_identity" "$app_dir"
open -n "$app_dir"
