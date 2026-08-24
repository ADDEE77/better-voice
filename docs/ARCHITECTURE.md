# Architecture

Better Voice is a small native Swift app with one executable target and one testable core target.

## Recording flow

1. Global modifier monitoring starts push-to-talk after a short `⌥` hold, or toggles long-form recording with `⌘⌥`.
2. `AVAudioEngine` records the selected microphone while the HUD displays its live level.
3. Native `Tink` and `Pop` cues mark the listening start and finish.
4. Mouse events feed `CircleGestureDetector`; the overlay renders the trail without appearing in screenshots.
5. A recognized gesture asks ScreenCaptureKit for the full display under the pointer, then draws the blue highlight into the saved PNG.
6. FluidAudio transcribes the temporary audio file locally.
7. `SessionOutput` writes `context.md`, updates the clipboard, and attempts native text insertion into the captured Accessibility target.
8. `SessionStorage` deletes sessions older than 7 days and keeps the remaining folder below 500 MB.

## Repository map

```text
Sources/BetterVoice/main.swift                 macOS app and system integrations
Sources/BetterVoice/SetupView.swift            onboarding and actionable recovery UI
Sources/BetterVoiceCore/CircleGestureDetector.swift
Sources/BetterVoiceCore/RecordingSoundCue.swift
Sources/BetterVoiceCore/RecordingShortcutState.swift
Sources/BetterVoiceCore/SessionCompletionPolicy.swift
Sources/BetterVoiceCore/SessionRetentionPolicy.swift
Sources/BetterVoiceCore/TrailSegments.swift   gesture logic shared with tests
Tests/BetterVoiceCoreTests/                    focused gesture tests
scripts/build-app.sh                           release build, signing, and launch
Info.plist                                     app identity and permission descriptions
```

The app keeps a stable bundle identifier and code signature because macOS TCC permissions are tied to app identity. Rebuilding with ad-hoc or different signing identities can make Screen Recording and Accessibility appear granted while the new executable is rejected.
