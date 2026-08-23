# Better Voice

Voice dictation with the screen context you point at.

Better Voice is an experimental macOS menu-bar app that records speech, transcribes it locally, and captures the parts of the screen you circle with your mouse. It is designed for prompts such as “make this button clearer” where the words and the visual reference belong together.

## How it works

1. Press `⌘⌥` (Command + Option) to start recording.
2. Speak normally. While recording, circle anything important with the pointer.
3. A blue trail follows the pointer and a blue ring confirms each capture.
4. Press `⌘⌥` again to stop.
5. Better Voice transcribes locally, inserts the transcript into the selected text field when possible, and places the transcript and captured images on the clipboard.

Each gesture captures the full display containing the pointer and marks the circled area with a restrained blue highlight. Multiple circles create multiple screenshots.

## Requirements

- macOS 14 or newer
- Xcode command-line tools with Swift 6
- A local Apple code-signing identity, so macOS permissions survive rebuilds
- Microphone, Screen Recording, and Accessibility permissions

## Build and run

```sh
git clone https://github.com/TarunTomar122/better-voice.git
cd better-voice
./scripts/build-app.sh
```

The script builds a release app at `.build/BetterVoice.app`, signs it, and launches it. To choose a specific signing identity:

```sh
BETTERVOICE_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build-app.sh
```

On first launch:

1. Grant Microphone, Screen Recording, and Accessibility access in System Settings.
2. Open the Better Voice menu-bar item.
3. Select **Download Local Model (~500 MB)**.
4. Choose an input from the **Microphone** submenu, or keep **Automatic**. Automatic prefers a connected external microphone and falls back to the system input.

The workflow uses FluidAudio's local Parakeet v2 model. Audio stays on the Mac and the temporary recording is removed after transcription.

## Clipboard behavior

macOS paste targets decide which clipboard representation they accept. Better Voice therefore:

- inserts the transcript back into the text field that was active when recording stopped, when Accessibility allows it;
- writes plain text, rich text, PNG, and TIFF representations to the clipboard;
- keeps every session on disk as a reliable fallback.

In editors that accept attachments, press `⌘V` once after recording to attach the captured images. Plain-text fields paste the transcript only.

## Saved sessions

Sessions are stored locally:

```text
~/Desktop/BetterVoice/<timestamp>-<id>/
├── context.md
├── context-1.png
└── context-2.png
```

## Development

Run the focused gesture and trail tests with:

```sh
swift test -Xswiftc -strict-concurrency=complete
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the compact implementation map.

## Current scope

- English transcription
- Fixed `⌘⌥` shortcut
- Source build; no notarized release yet
- Circle detection is intentionally forgiving and does not require a perfect circle

Built for personal experimentation and inspired by the fluidity of Wispr Flow. Better Voice is not affiliated with Wispr Flow.
