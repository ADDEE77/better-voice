#!/bin/zsh
set -euo pipefail

swift build -c release
app_dir=".build/BetterVoice.app"
if pgrep -x BetterVoice >/dev/null; then
  osascript -e 'tell application id "com.tarun.bettervoice" to quit'
  for _ in {1..50}; do
    pgrep -x BetterVoice >/dev/null || break
    sleep 0.1
  done
  if pgrep -x BetterVoice >/dev/null; then
    print -u2 "BetterVoice did not quit cleanly; close it and run the build again."
    exit 1
  fi
fi
rm -rf ".build/BetterVoice.app"
mkdir -p "$app_dir/Contents/MacOS"
cp ".build/release/BetterVoice" "$app_dir/Contents/MacOS/BetterVoice"
cp "Info.plist" "$app_dir/Contents/Info.plist"
mkdir -p "$app_dir/Contents/Resources"
cp "Resources/BetterVoice.icns" "$app_dir/Contents/Resources/BetterVoice.icns"
signing_identity=${BETTERVOICE_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | awk 'NR == 1 { print $2 }')}
if [[ -z "$signing_identity" ]]; then
  print -u2 "BetterVoice needs a stable code-signing identity so macOS permissions survive rebuilds."
  exit 1
fi
codesign --force --deep --sign "$signing_identity" "$app_dir"
if [[ "${BETTERVOICE_SKIP_OPEN:-0}" != "1" ]]; then
  open -n "$app_dir"
fi
