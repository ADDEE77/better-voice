# Architecture

Better Voice is a small native Swift app with one executable target and one testable core target.

## Recording flow

1. Global modifier monitoring toggles a recording session with `⌘⌥`.
2. `AVAudioEngine` records the selected microphone while the HUD displays its live level.
3. Mouse events feed `CircleGestureDetector`; the overlay renders the trail without appearing in screenshots.
4. A recognized gesture asks ScreenCaptureKit for the full display under the pointer, then draws the blue highlight into the saved PNG.
5. FluidAudio transcribes the temporary audio file locally.
6. `SessionOutput` writes `context.md`, updates the clipboard, and attempts native text insertion into the captured Accessibility target.

## Repository map

```text
Sources/BetterVoice/main.swift                 macOS app and system integrations
Sources/BetterVoiceCore/CircleGestureDetector.swift
Sources/BetterVoiceCore/TrailSegments.swift   gesture logic shared with tests
Tests/BetterVoiceCoreTests/                    focused gesture tests
scripts/build-app.sh                           release build, signing, and launch
Info.plist                                     app identity and permission descriptions
```

The app keeps a stable bundle identifier and code signature because macOS TCC permissions are tied to app identity. Rebuilding with ad-hoc signatures can make Screen Recording and Accessibility appear granted while the new executable is rejected.
