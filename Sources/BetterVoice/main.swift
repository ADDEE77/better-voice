import AppKit
import AVFoundation
import CoreGraphics
import BetterVoiceCore
import Speech

private enum BetterVoiceError: LocalizedError {
    case microphoneUnavailable
    case speechUnavailable
    case screenshotUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable: return "No microphone input is available."
        case .speechUnavailable: return "Speech recognition is unavailable."
        case .screenshotUnavailable: return "The screen could not be captured. Enable Screen Recording for BetterVoice."
        }
    }
}

private final class SpeechRecorder: NSObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var finishing: ((String) -> Void)?

    var onTranscript: ((String) -> Void)?

    func start() throws {
        guard let recognizer, recognizer.isAvailable else { throw BetterVoiceError.speechUnavailable }
        guard audioEngine.inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            throw BetterVoiceError.microphoneUnavailable
        }

        latestTranscript = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw BetterVoiceError.speechUnavailable }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
                self.onTranscript?(self.latestTranscript)
                if result.isFinal { self.finishIfNeeded() }
            } else if error != nil {
                self.finishIfNeeded()
            }
        }

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputNode.inputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop(completion: @escaping (String) -> Void) {
        finishing = completion
        request?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionTask?.finish()

        // Speech can emit its final result asynchronously; this keeps stop deterministic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.finishIfNeeded()
        }
    }

    private func finishIfNeeded() {
        guard let finishing else { return }
        self.finishing = nil
        recognitionTask = nil
        request = nil
        finishing(latestTranscript)
    }
}

private final class ScreenshotCapture {
    static func capture(gesture: CircleGesture, to url: URL) throws {
        let side = max(180, min(720, gesture.radius * 3.2))
        let region = CGRect(
            x: gesture.center.x - side / 2,
            y: gesture.center.y - side / 2,
            width: side,
            height: side
        )
        guard let image = CGWindowListCreateImage(
            region,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw BetterVoiceError.screenshotUnavailable
        }

        let marked = mark(image, target: gesture.center, region: region, radius: gesture.radius)
        let representation = NSBitmapImageRep(cgImage: marked)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw BetterVoiceError.screenshotUnavailable
        }
        try data.write(to: url, options: .atomic)
    }

    private static func mark(_ image: CGImage, target: CGPoint, region: CGRect, radius: CGFloat) -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scaleX = CGFloat(width) / region.width
        let scaleY = CGFloat(height) / region.height
        let x = (target.x - region.minX) * scaleX
        let y = CGFloat(height) - (target.y - region.minY) * scaleY
        let markedRadius = max(18, radius * min(scaleX, scaleY))
        let marker = CGRect(x: x - markedRadius, y: y - markedRadius, width: markedRadius * 2, height: markedRadius * 2)

        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(max(4, markedRadius * 0.08))
        context.strokeEllipse(in: marker)
        context.setLineWidth(max(2, markedRadius * 0.04))
        context.move(to: CGPoint(x: x - markedRadius * 1.25, y: y))
        context.addLine(to: CGPoint(x: x + markedRadius * 1.25, y: y))
        context.move(to: CGPoint(x: x, y: y - markedRadius * 1.25))
        context.addLine(to: CGPoint(x: x, y: y + markedRadius * 1.25))
        context.strokePath()
        return context.makeImage() ?? image
    }
}

private final class SessionOutput {
    let folder: URL
    private(set) var images: [URL] = []

    init() throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = desktop.appendingPathComponent("BetterVoice", isDirectory: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        folder = root.appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func addImage(for gesture: CircleGesture) throws -> URL {
        let url = folder.appendingPathComponent("context-\(images.count + 1).png")
        try ScreenshotCapture.capture(gesture: gesture, to: url)
        images.append(url)
        return url
    }

    func finish(transcript: String) throws -> URL {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.isEmpty ? "(No transcript captured.)" : trimmed
        var markdown = "# BetterVoice session\n\n\(text)\n"
        if !images.isEmpty {
            markdown += "\n## Screen context\n\n"
            for (index, image) in images.enumerated() {
                markdown += "![Context \(index + 1)](\(image.lastPathComponent))\n\n"
            }
        }
        let markdownURL = folder.appendingPathComponent("context.md")
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        let paths = images.enumerated().map { "Context \($0.offset + 1): \($0.element.path)" }.joined(separator: "\n")
        let clipboardText = images.isEmpty ? text : "\(text)\n\nScreen context:\n\(paths)"
        Clipboard.copy(transcript: text, images: images, text: clipboardText)
        print(clipboardText)
        return markdownURL
    }
}

private enum Clipboard {
    static func copy(transcript: String, images: [URL], text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let rich = NSMutableAttributedString(string: transcript + (images.isEmpty ? "" : "\n\n"))
        for (index, imageURL) in images.enumerated() {
            if let image = NSImage(contentsOf: imageURL) {
                let attachment = NSTextAttachment()
                attachment.image = image
                rich.append(NSAttributedString(attachment: attachment))
                rich.append(NSAttributedString(string: "\nContext \(index + 1)\n\n"))
            }
        }

        let item = NSPasteboardItem()
        if let rtf = try? rich.data(
            from: NSRange(location: 0, length: rich.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            item.setData(rtf, forType: .rtf)
        }
        item.setString(text, forType: .string)
        pasteboard.writeObjects([item])
    }
}

private final class InputMonitor {
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private let toggle: () -> Void
    private let mouseMoved: (CGPoint) -> Void

    init(toggle: @escaping () -> Void, mouseMoved: @escaping (CGPoint) -> Void) {
        self.toggle = toggle
        self.mouseMoved = mouseMoved
    }

    func start() {
        let keyHandler: (NSEvent) -> Void = { [weak self] event in
            guard let self, Self.isTrigger(event) else { return }
            self.toggle()
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyHandler)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, Self.isTrigger(event) else { return event }
            self.toggle()
            return nil
        }

        let mouseHandler: (NSEvent) -> Void = { [weak self] event in
            guard let location = event.cgEvent?.location else { return }
            self?.mouseMoved(location)
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: mouseHandler)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            if let location = event.cgEvent?.location { self?.mouseMoved(location) }
            return event
        }
    }

    deinit {
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMouseMonitor { NSEvent.removeMonitor(monitor) }
    }

    private static func isTrigger(_ event: NSEvent) -> Bool {
        event.type == .keyDown && event.keyCode == 49 && event.modifierFlags.contains(.option)
    }
}

private final class AppController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speech = SpeechRecorder()
    private var inputMonitor: InputMonitor?
    private var detector = CircleGestureDetector()
    private var output: SessionOutput?
    private var transcript = ""
    private var isRecording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = "BetterVoice"
        let menu = NSMenu()
        let recordingItem = NSMenuItem(title: "Start recording (⌥ Space)", action: #selector(toggleRecording), keyEquivalent: "")
        recordingItem.target = self
        menu.addItem(recordingItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit BetterVoice", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        inputMonitor = InputMonitor(
            toggle: { [weak self] in self?.toggleRecording() },
            mouseMoved: { [weak self] point in self?.handleMouse(point) }
        )
        inputMonitor?.start()
        requestSpeechAuthorization()
        requestMicrophoneAuthorization()
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        do {
            output = try SessionOutput()
            detector.reset()
            transcript = ""
            speech.onTranscript = { [weak self] value in
                self?.transcript = value
                self?.statusItem.button?.title = "Recording…"
            }
            try speech.start()
            isRecording = true
            statusItem.button?.title = "Recording…"
            updateMenuTitle("Stop recording (⌥ Space)")
        } catch {
            output = nil
            showError(error.localizedDescription)
        }
    }

    private func stopRecording() {
        isRecording = false
        statusItem.button?.title = "Finishing…"
        updateMenuTitle("Start recording (⌥ Space)")
        speech.stop { [weak self] finalTranscript in
            guard let self else { return }
            self.transcript = finalTranscript.isEmpty ? self.transcript : finalTranscript
            do {
                let markdownURL = try self.output?.finish(transcript: self.transcript)
                self.output = nil
                self.statusItem.button?.title = "BetterVoice"
                if let markdownURL { self.showNotice("Copied transcript + context\n\(markdownURL.path)") }
            } catch {
                self.output = nil
                self.statusItem.button?.title = "BetterVoice"
                self.showError(error.localizedDescription)
            }
        }
    }

    private func handleMouse(_ point: CGPoint) {
        guard isRecording, let gesture = detector.add(point: point, at: ProcessInfo.processInfo.systemUptime) else { return }
        do {
            guard let output else { return }
            _ = try output.addImage(for: gesture)
            statusItem.button?.title = "Recording • \(output.images.count)"
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async { self.showError("Allow Speech Recognition in System Settings to transcribe speech.") }
            }
        }
    }

    private func requestMicrophoneAuthorization() {
        let handle: (Bool) -> Void = { granted in
            if !granted {
                DispatchQueue.main.async { self.showError("Allow Microphone access in System Settings to record speech.") }
            }
        }
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handle)
        } else {
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: handle)
        }
    }

    private func updateMenuTitle(_ title: String) {
        statusItem.menu?.item(at: 0)?.title = title
    }

    private func showNotice(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "BetterVoice"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showError(_ message: String) {
        NSSound.beep()
        showNotice(message)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
private let delegate = AppController()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
