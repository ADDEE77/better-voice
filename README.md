# BetterVoice MVP

BetterVoice is a small macOS menu-bar app for speech plus screen context.

1. Build and launch it:

   ```sh
   ./scripts/build-app.sh
   ```

2. On first launch, allow Microphone, Screen Recording, and Accessibility access. Accessibility is needed for the global keyboard and mouse gesture.
3. Click `Download Local Model (~500 MB)` in the menu-bar menu. BetterVoice downloads Parakeet v2 once and keeps transcription on device.
4. Choose `System Default` or a connected input from the `Microphone` submenu. The selected device is shown in the recording capsule.
5. Press `⌘⌥` (Command + Option) once to start recording and once again to stop.
6. While recording, speak and draw a closed circle around anything important. A short blue pointer tail follows the cursor; a blue confirmation ring means a marked screenshot was captured.
7. BetterVoice transcribes locally after you stop, deletes the temporary audio file, copies the transcript and PNG context to the clipboard, and saves a Markdown session under `~/Desktop/BetterVoice/`.

The menu-bar icon pulses while recording and a compact bottom-center capsule shows the active microphone, live input level, and screenshot count. Completion and errors stay in the menu status line; no modal interrupts the workflow.

The clipboard contains transcript text, RTF image attachments, and each screenshot as a PNG/TIFF pasteboard item—never a file path. Rich editors can paste the images; plain-text fields paste only the transcript. The fixed `⌘⌥` shortcut and English-only model are deliberate MVP limits.
