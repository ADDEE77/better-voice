import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import BetterVoiceCore
import Speech

private enum BetterVoiceError: LocalizedError {
    case microphoneUnavailable
    case speechUnavailable
    case sessionUnavailable
    case screenshotUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable: return "No microphone input is available."
        case .speechUnavailable: return "Speech recognition is unavailable."
        case .sessionUnavailable: return "The recording session is no longer available."
        case .screenshotUnavailable: return "The screen could not be captured. Enable Screen Recording for BetterVoice."
        }
    }
}

@MainActor
private final class SpeechRecorder: NSObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var recognitionError: Error?
    private var recognitionFinished = false
    private var activeID: UUID?
    private var pendingFinish: (id: UUID, completion: (Result<String, Error>) -> Void)?
    private let partialFinalizationTimeout: TimeInterval = 3
    private let coldFinalizationTimeout: TimeInterval = 8

    var onTranscript: ((String) -> Void)?

    func start() throws {
        precondition(activeID == nil && pendingFinish == nil)
        guard let recognizer, recognizer.isAvailable else { throw BetterVoiceError.speechUnavailable }
        guard audioEngine.inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            throw BetterVoiceError.microphoneUnavailable
        }

        let id = UUID()
        activeID = id
        latestTranscript = ""
        recognitionError = nil
        recognitionFinished = false
        let audioRequest = SFSpeechAudioBufferRecognitionRequest()
        request = audioRequest
        audioRequest.shouldReportPartialResults = true
        audioRequest.taskHint = .dictation
        audioRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        recognitionTask = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handle(result: result, error: error, id: id)
            }
        }

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputNode.inputFormat(forBus: 0)) { buffer, _ in
            audioRequest.append(buffer)
        }
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            recognitionTask?.cancel()
            recognitionTask = nil
            self.request = nil
            recognitionError = nil
            recognitionFinished = false
            activeID = nil
            throw error
        }
    }

    func stop(completion: @escaping (Result<String, Error>) -> Void) {
        guard let id = activeID else {
            completion(recognitionResult())
            return
        }
        pendingFinish = (id, completion)
        request?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionTask?.finish()

        if recognitionFinished {
            finishIfNeeded(id: id)
            return
        }

        let timeout = latestTranscript.isEmpty ? coldFinalizationTimeout : partialFinalizationTimeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finishIfNeeded(id: id)
        }
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?, id: UUID) {
        guard activeID == id else { return }
        if let result {
            latestTranscript = result.bestTranscription.formattedString
            onTranscript?(latestTranscript)
            if result.isFinal { recognitionFinished = true }
        }
        if let error {
            recognitionError = error
            recognitionFinished = true
        }
        if recognitionFinished {
            finishIfNeeded(id: id)
        }
    }

    private func finishIfNeeded(id: UUID) {
        guard activeID == id, let pendingFinish, pendingFinish.id == id else { return }
        self.pendingFinish = nil
        activeID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        let result = recognitionResult()
        recognitionError = nil
        recognitionFinished = false
        onTranscript = nil
        pendingFinish.completion(result)
    }

    private func recognitionResult() -> Result<String, Error> {
        if let recognitionError { return .failure(recognitionError) }
        return .success(latestTranscript)
    }
}

@MainActor
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

        let marked = try mark(image, target: gesture.center, region: region, radius: gesture.radius)
        let representation = NSBitmapImageRep(cgImage: marked)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw BetterVoiceError.screenshotUnavailable
        }
        try data.write(to: url, options: .atomic)
    }

    private static func mark(_ image: CGImage, target: CGPoint, region: CGRect, radius: CGFloat) throws -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BetterVoiceError.screenshotUnavailable
        }
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

private struct TrailPoint {
    let point: CGPoint
    let time: TimeInterval
}

private struct TrailConfirmation {
    let center: CGPoint
    let radius: CGFloat
    let startedAt: TimeInterval
}

@MainActor
private final class TrailOverlayView: NSView {
    private let trailLifetime: TimeInterval = 1.2
    private let confirmationLifetime: TimeInterval = 0.55
    private var trail: [TrailPoint] = []
    private var confirmations: [TrailConfirmation] = []
    private var globalOrigin = CGPoint.zero
    var reduceMotion = false

    func setGlobalOrigin(_ origin: CGPoint) {
        globalOrigin = origin
    }

    func add(point: CGPoint, at time: TimeInterval) {
        trail.append(TrailPoint(point: point, time: time))
        prune(now: time)
        needsDisplay = true
    }

    func confirm(center: CGPoint, radius: CGFloat, at time: TimeInterval) {
        confirmations.append(TrailConfirmation(center: center, radius: radius, startedAt: time))
        needsDisplay = true
    }

    func tick(now: TimeInterval) {
        prune(now: now)
        needsDisplay = true
    }

    func reset() {
        trail.removeAll(keepingCapacity: true)
        confirmations.removeAll(keepingCapacity: true)
        needsDisplay = false
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let now = ProcessInfo.processInfo.systemUptime

        context.setLineCap(.round)
        for index in trailSegmentRange(pointCount: trail.count) {
            let previous = trail[index - 1]
            let current = trail[index]
            let age = max(0, now - current.time)
            let fade = max(0, 1 - age / trailLifetime)
            guard fade > 0 else { continue }
            context.move(to: localPoint(previous.point))
            context.addLine(to: localPoint(current.point))
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.18 * fade).cgColor)
            context.setLineWidth(11)
            context.strokePath()

            context.move(to: localPoint(previous.point))
            context.addLine(to: localPoint(current.point))
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.96 * fade).cgColor)
            context.setLineWidth(4)
            context.strokePath()
        }

        for confirmation in confirmations {
            let age = max(0, now - confirmation.startedAt)
            let progress = min(1, age / confirmationLifetime)
            let alpha = max(0, 0.82 * (1 - progress))
            guard alpha > 0 else { continue }
            let scale = reduceMotion ? 1 : 0.82 + 0.18 * progress
            let radius = confirmation.radius * scale
            let center = localPoint(confirmation.center)
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(alpha * 0.12).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(4)
            context.strokeEllipse(in: rect)
        }
    }

    private func localPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - globalOrigin.x, y: point.y - globalOrigin.y)
    }

    private func prune(now: TimeInterval) {
        trail.removeAll { now - $0.time > trailLifetime }
        confirmations.removeAll { now - $0.startedAt > confirmationLifetime }
    }
}

@MainActor
private final class TrailOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class TrailOverlayController {
    private let view = TrailOverlayView(frame: .zero)
    private var window: TrailOverlayWindow?
    private var timer: Timer?

    func start() {
        stop()
        view.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let frames = NSScreen.screens.map(\.frame)
        guard var frame = frames.first else { return }
        for screenFrame in frames.dropFirst() {
            frame = frame.union(screenFrame)
        }

        let overlay = TrailOverlayWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true
        overlay.level = .screenSaver
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        overlay.sharingType = .none
        overlay.animationBehavior = .none
        view.setGlobalOrigin(frame.origin)
        view.frame = CGRect(origin: .zero, size: frame.size)
        overlay.contentView = view
        window = overlay
        overlay.orderFrontRegardless()

        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        view.reset()
        window?.orderOut(nil)
        window = nil
    }

    func add(point: CGPoint, at time: TimeInterval) {
        guard window != nil else { return }
        view.add(point: point, at: time)
    }

    func confirm(center: CGPoint, radius: CGFloat, at time: TimeInterval) {
        guard window != nil else { return }
        view.confirm(center: center, radius: radius, at: time)
    }

    private func tick() {
        view.tick(now: ProcessInfo.processInfo.systemUptime)
    }
}

@MainActor
private final class SessionOutput {
    let folder: URL
    private(set) var images: [URL] = []

    init() throws {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = desktop.appendingPathComponent("BetterVoice", isDirectory: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        folder = root.appendingPathComponent("\(stamp)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func addImage(for gesture: CircleGesture) throws -> URL {
        let url = folder.appendingPathComponent("context-\(images.count + 1).png")
        try ScreenshotCapture.capture(gesture: gesture, to: url)
        images.append(url)
        return url
    }

    func finish(transcript: String) throws -> (markdownURL: URL, clipboardCopied: Bool) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        var markdown = "# BetterVoice session\n\n"
        markdown += trimmed.isEmpty ? "_No transcript captured._\n" : "\(trimmed)\n"
        if !images.isEmpty {
            markdown += "\n## Screen context\n\n"
            for (index, image) in images.enumerated() {
                markdown += "![Context \(index + 1)](\(image.lastPathComponent))\n\n"
            }
        }
        let markdownURL = folder.appendingPathComponent("context.md")
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        let paths = images.enumerated().map { "Context \($0.offset + 1): \($0.element.path)" }.joined(separator: "\n")
        var clipboardSections: [String] = []
        if !trimmed.isEmpty { clipboardSections.append(trimmed) }
        if !images.isEmpty { clipboardSections.append("Screen context:\n\(paths)") }
        let clipboardText = clipboardSections.joined(separator: "\n\n")
        let clipboardCopied = Clipboard.copy(transcript: trimmed, images: images, text: clipboardText)
        print(clipboardText)
        return (markdownURL, clipboardCopied)
    }
}

@MainActor
private enum Clipboard {
    static func copy(transcript: String, images: [URL], text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        guard item.setString(text, forType: .string) else { return false }
        guard !images.isEmpty else { return pasteboard.writeObjects([item]) }

        let rich = NSMutableAttributedString(string: transcript + (images.isEmpty ? "" : "\n\n"))
        var imageItems: [NSPasteboardItem] = []
        for (index, imageURL) in images.enumerated() {
            guard let data = try? Data(contentsOf: imageURL), let image = NSImage(data: data) else {
                _ = pasteboard.writeObjects([item])
                return false
            }
            let attachment = NSTextAttachment()
            attachment.image = image
            rich.append(NSAttributedString(attachment: attachment))
            rich.append(NSAttributedString(string: "\nContext \(index + 1)\n\n"))

            let imageItem = NSPasteboardItem()
            guard imageItem.setData(data, forType: .png),
                  imageItem.setString(imageURL.absoluteString, forType: .fileURL) else {
                _ = pasteboard.writeObjects([item])
                return false
            }
            imageItems.append(imageItem)
        }

        guard let rtf = try? rich.data(
            from: NSRange(location: 0, length: rich.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ), item.setData(rtf, forType: .rtf) else {
            _ = pasteboard.writeObjects([item])
            return false
        }
        let objects: [NSPasteboardWriting] = [item] + imageItems
        guard pasteboard.writeObjects(objects) else {
            _ = pasteboard.writeObjects([item])
            return false
        }
        return true
    }
}

@MainActor
private final class InputMonitor {
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var chordLatched = false
    private let toggle: () -> Void
    private let mouseMoved: (CGPoint) -> Void

    init(toggle: @escaping () -> Void, mouseMoved: @escaping (CGPoint) -> Void) {
        self.toggle = toggle
        self.mouseMoved = mouseMoved
    }

    func start() {
        chordLatched = false
        let flagsHandler: (NSEvent) -> Void = { [weak self] event in
            DispatchQueue.main.async { self?.handleFlags(event.modifierFlags) }
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flagsHandler)
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async { self?.handleFlags(event.modifierFlags) }
            return event
        }

        let mouseHandler: (NSEvent) -> Void = { [weak self] event in
            guard let location = event.cgEvent?.location else { return }
            DispatchQueue.main.async { self?.mouseMoved(location) }
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: mouseHandler)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            if let location = event.cgEvent?.location {
                DispatchQueue.main.async { self?.mouseMoved(location) }
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalFlagsMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localFlagsMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMouseMonitor { NSEvent.removeMonitor(monitor) }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let normalized = flags.intersection(.deviceIndependentFlagsMask)
        let chordHeld = normalized.contains(.command) && normalized.contains(.option)
        if chordHeld {
            guard !chordLatched else { return }
            chordLatched = true
            toggle()
        } else {
            chordLatched = false
        }
    }
}

private enum SessionState {
    case idle
    case recording
    case finishing
}

private enum StatusIconState {
    case idle
    case recording
    case finishing
}

@MainActor
private final class AppController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speech = SpeechRecorder()
    private let trailOverlay = TrailOverlayController()
    private var inputMonitor: InputMonitor?
    private var detector = CircleGestureDetector()
    private var output: SessionOutput?
    private var transcript = ""
    private var state = SessionState.idle
    private var statusMenuItem: NSMenuItem?
    private var recordingMenuItem: NSMenuItem?
    private var statusAnimationTimer: Timer?
    private var statusFeedbackTimer: Timer?
    private var statusPulse = false
    private var reduceMotion = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        setStatusIcon(.idle)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = "BetterVoice — hold ⌘⌥ to record"

        let menu = NSMenu()
        let statusMenuItem = NSMenuItem(title: "Ready • hold ⌘⌥ to record", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        self.statusMenuItem = statusMenuItem
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        let recordingItem = NSMenuItem(title: "Start recording (⌘⌥)", action: #selector(toggleRecording), keyEquivalent: "")
        recordingItem.target = self
        recordingMenuItem = recordingItem
        menu.addItem(recordingItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit BetterVoice", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        inputMonitor = InputMonitor(
            toggle: { [weak self] in self?.toggleRecording() },
            mouseMoved: { [weak self] quartzPoint in
                self?.handleMouse(quartzPoint: quartzPoint)
            }
        )
        inputMonitor?.start()
        requestSpeechAuthorization()
        requestMicrophoneAuthorization()
        requestSystemPermissions()
    }

    @objc private func toggleRecording() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .finishing:
            break
        }
    }

    private func startRecording() {
        do {
            output = try SessionOutput()
            detector.reset()
            transcript = ""
            speech.onTranscript = { [weak self] value in
                self?.transcript = value
            }
            try speech.start()
            state = .recording
            trailOverlay.start()
            setStatusIcon(.recording)
            showStatus("Recording…")
            updateMenuTitle("Stop recording (⌘⌥)", enabled: true)
        } catch {
            output = nil
            showError(error.localizedDescription)
        }
    }

    private func stopRecording() {
        guard state == .recording else { return }
        state = .finishing
        trailOverlay.stop()
        setStatusIcon(.finishing)
        showStatus("Finishing…")
        updateMenuTitle("Finishing… (⌘⌥)", enabled: false)
        speech.stop { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let finalTranscript):
                if !finalTranscript.isEmpty { self.transcript = finalTranscript }
                self.finishSession()
            case .failure(let error):
                self.finishSession(speechError: error)
            }
        }
    }

    private func finishSession(speechError: Error? = nil) {
        let session = output
        let hadTranscript = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        do {
            guard let session else { throw BetterVoiceError.sessionUnavailable }
            let result = try session.finish(transcript: transcript)
            let hasContext = !session.images.isEmpty
            output = nil
            state = .idle
            setStatusIcon(.idle)
            updateMenuTitle("Start recording (⌘⌥)", enabled: true)

            if let speechError {
                let delivery = result.clipboardCopied
                    ? (hasContext ? "Screen context copied." : "Session saved.")
                    : "Session saved; clipboard text fallback used."
                showError("Speech recognition failed: \(speechError.localizedDescription) \(delivery)")
            } else if result.clipboardCopied {
                if hadTranscript && hasContext {
                    showStatus("Copied transcript + context", resetAfter: 4)
                } else if hadTranscript {
                    showStatus("Copied transcript", resetAfter: 4)
                } else if hasContext {
                    showStatus("No speech detected • context copied", resetAfter: 4)
                } else {
                    showStatus("No speech detected • session saved", resetAfter: 4)
                }
            } else {
                showError("Saved session; plain-text clipboard fallback used.")
            }
        } catch {
            output = nil
            state = .idle
            setStatusIcon(.idle)
            updateMenuTitle("Start recording (⌘⌥)", enabled: true)
            if let speechError {
                showError("Speech recognition failed: \(speechError.localizedDescription); session save failed: \(error.localizedDescription)")
            } else {
                showError(error.localizedDescription)
            }
        }
    }

    private func handleMouse(quartzPoint: CGPoint) {
        guard state == .recording else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let overlayPoint = appKitPoint(from: quartzPoint)
        trailOverlay.add(point: overlayPoint, at: now)
        guard let gesture = detector.add(point: quartzPoint, at: now) else { return }
        let appKitCenter = appKitPoint(from: gesture.center)
        trailOverlay.confirm(center: appKitCenter, radius: gesture.radius, at: now)
        do {
            guard let output else { return }
            _ = try output.addImage(for: gesture)
            showStatus("Recording • \(output.images.count) screen context")
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func appKitPoint(from quartzPoint: CGPoint) -> CGPoint {
        guard let primaryFrame = NSScreen.screens.first?.frame else { return quartzPoint }
        return CGPoint(
            x: quartzPoint.x + primaryFrame.minX,
            y: primaryFrame.maxY - quartzPoint.y
        )
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async { self.showError("Allow Speech Recognition in System Settings to transcribe speech.") }
            }
        }
    }

    private func requestMicrophoneAuthorization() {
        if #available(macOS 14.0, *) {
            let controller = self
            AVAudioApplication.requestRecordPermission { granted in
                guard !granted else { return }
                DispatchQueue.main.async { [weak controller] in
                    controller?.showError("Allow Microphone access in System Settings to record speech.")
                }
            }
        } else {
            let controller = self
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard !granted else { return }
                DispatchQueue.main.async { [weak controller] in
                    controller?.showError("Allow Microphone access in System Settings to record speech.")
                }
            }
        }
    }

    private func requestSystemPermissions() {
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func updateMenuTitle(_ title: String, enabled: Bool) {
        recordingMenuItem?.title = title
        recordingMenuItem?.isEnabled = enabled
    }

    private func showStatus(_ message: String, resetAfter: TimeInterval? = nil) {
        statusFeedbackTimer?.invalidate()
        statusFeedbackTimer = nil
        statusMenuItem?.title = message
        statusItem.button?.toolTip = "BetterVoice — \(message)"

        guard let resetAfter else { return }
        let timer = Timer(timeInterval: resetAfter, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.state == .idle else { return }
                self.showStatus("Ready • hold ⌘⌥ to record")
            }
        }
        statusFeedbackTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func setStatusIcon(_ state: StatusIconState) {
        statusAnimationTimer?.invalidate()
        statusAnimationTimer = nil

        switch state {
        case .idle, .finishing:
            setIcon(named: "waveform")
        case .recording:
            statusPulse = false
            setIcon(named: "waveform.circle.fill")
            guard !reduceMotion else { return }
            let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.state == .recording else { return }
                    self.statusPulse.toggle()
                    self.setIcon(named: self.statusPulse ? "waveform.circle" : "waveform.circle.fill")
                }
            }
            statusAnimationTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func setIcon(named name: String) {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "BetterVoice")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func showError(_ message: String) {
        NSSound.beep()
        showStatus("Error: \(message)", resetAfter: 6)
    }

    @objc private func quit() {
        inputMonitor?.stop()
        trailOverlay.stop()
        statusAnimationTimer?.invalidate()
        statusFeedbackTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
private let delegate = MainActor.assumeIsolated { AppController() }
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
