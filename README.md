# BetterVoice MVP

BetterVoice is a small macOS menu-bar app for speech plus screen context.

1. Build and launch it:

   ```sh
   ./scripts/build-app.sh
   ```

2. On first launch, BetterVoice calls macOS's native checks/requests for Microphone, Speech Recognition, Screen Recording, and Accessibility access. macOS may open System Settings instead of showing an in-app prompt. If either Screen Recording or Accessibility remains disabled, enable BetterVoice in System Settings → Privacy & Security → Screen Recording and Accessibility, then relaunch. Accessibility is needed for global keyboard/mouse monitoring.
3. Hold `⌘⌥` (Command + Option) to start recording; release either modifier to unlatch the chord.
4. While recording, the desktop shows a click-through blue mouse trail. Speak while drawing a closed circle with the mouse around anything on screen. Each recognized circle briefly flashes a blue confirmation ring and saves a marked PNG.
5. Hold `⌘⌥` again to stop. BetterVoice transcribes the latest speech, copies the transcript and captured image context to the clipboard, and writes a Markdown session folder to `~/Desktop/BetterVoice/`.

The menu-bar icon is a native waveform symbol: it pulses while recording unless Reduce Motion is enabled. Completion and errors appear in the menu status line and icon tooltip; no modal alert interrupts the workflow. The Command + Option chord is fixed for this MVP and can become configurable later.

The clipboard includes transcript text, RTF image attachments, and each captured PNG as a separate PNG/file-URL pasteboard item. Absolute PNG paths remain in the plain-text fallback. Destination support varies: apps that accept multiple pasteboard items can attach the images, while plain-text fields may paste only the text. Screen recording and speech permissions are required by macOS; the app does not save raw audio. Recognition errors and empty speech results are reported in the menu status line.
