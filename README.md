# BetterVoice MVP

BetterVoice is a small macOS menu-bar app for speech plus screen context.

1. Build and launch it:

   ```sh
   ./scripts/build-app.sh
   ```

2. On first launch, BetterVoice calls macOS's native checks/requests for Microphone, Speech Recognition, Screen Recording, and Accessibility access. macOS may open System Settings instead of showing an in-app prompt. If either Screen Recording or Accessibility remains disabled, enable BetterVoice in System Settings → Privacy & Security → Screen Recording and Accessibility, then relaunch. Accessibility is needed for global keyboard/mouse monitoring.
3. Press `⌥ Space` to start recording.
4. Speak while drawing a closed circle with the mouse around anything on screen. Each recognized circle saves a marked PNG.
5. Press `⌥ Space` again. BetterVoice transcribes the latest speech, copies transcript plus rich image context to the clipboard, and writes a Markdown session folder to `~/Desktop/BetterVoice/`.

The clipboard includes transcript plus absolute PNG paths as a plain-text fallback and RTF with image attachments for rich-text destinations. Screen recording and speech permissions are required by macOS; the app does not save raw audio.
