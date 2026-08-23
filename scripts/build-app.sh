#!/bin/zsh
set -euo pipefail

swift build -c release
app_dir=".build/BetterVoice.app"
rm -rf ".build/BetterVoice.app"
mkdir -p "$app_dir/Contents/MacOS"
cp ".build/release/BetterVoice" "$app_dir/Contents/MacOS/BetterVoice"
cp "Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"
open -n "$app_dir"
