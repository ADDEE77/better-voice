import AppKit
import ApplicationServices
import AudioToolbox
import AVFoundation
import CoreAudio
import CoreGraphics
import BetterVoiceCore
import FluidAudio

private enum BetterVoiceError: LocalizedError {
    case microphoneUnavailable
    case microphoneSelectionUnavailable(String)
    case microphoneRoutingFailed(String, OSStatus)
    case localModelUnavailable
    case sessionUnavailable
    case screenshotUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable: return "No microphone input is available."
        case .microphoneSelectionUnavailable(let name): return "Selected microphone is unavailable: \(name). Choose another microphone from the menu."
        case .microphoneRoutingFailed(let name, let status): return "Could not route audio from \(name) (AudioUnit error \(status))."
        case .localModelUnavailable: return "Download the Local Parakeet model from the BetterVoice menu first."
        case .sessionUnavailable: return "The recording session is no longer available."
        case .screenshotUnavailable: return "The screen could not be captured. Enable Screen Recording for BetterVoice."
        }
    }
}

private struct MicrophoneDevice: Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

@MainActor
private final class MicrophoneManager {
    private let selectedUIDKey = "selectedMicrophoneUID"
    private(set) var devices: [MicrophoneDevice] = []

    var selectedUID: String? {
        UserDefaults.standard.string(forKey: selectedUIDKey)
    }

    var selectedDevice: MicrophoneDevice? {
        guard let selectedUID else { return nil }
        return devices.first { $0.uid == selectedUID }
    }

    var selectionUnavailable: Bool {
        selectedUID != nil && selectedDevice == nil
    }

    var recordingDevice: MicrophoneDevice? {
        if selectedUID != nil { return selectedDevice }
        guard let id = Self.defaultInputDeviceID(),
              Self.hasInputChannels(id),
              let uid = Self.stringProperty(id, selector: kAudioDevicePropertyDeviceUID),
              let name = Self.deviceName(for: id) else { return nil }
        return MicrophoneDevice(id: id, uid: uid, name: name)
    }

    var selectedLabel: String {
        if let selectedDevice { return selectedDevice.name }
        if let selectedUID { return "Unavailable (\(selectedUID))" }
        return "System Default — \(systemDefaultName)"
    }

    var systemDefaultName: String {
        guard let deviceID = Self.defaultInputDeviceID() else { return "Unavailable" }
        return devices.first { $0.id == deviceID }?.name
            ?? Self.deviceName(for: deviceID)
            ?? "Unavailable"
    }

    func refresh() {
        devices = Self.enumerateInputDevices()
    }

    func select(uid: String?) {
        if let uid {
            UserDefaults.standard.set(uid, forKey: selectedUIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedUIDKey)
        }
    }

    private static func enumerateInputDevices() -> [MicrophoneDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.stride
        guard count > 0 else { return [] }
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = deviceIDs.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { deviceID in
            guard hasInputChannels(deviceID),
                  let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID),
                  let name = deviceName(for: deviceID) else { return nil }
            return MicrophoneDevice(id: deviceID, uid: uid, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return false }

        let rawBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBuffer.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, rawBuffer) == noErr else {
            return false
        }
        let bufferList = UnsafeMutableAudioBufferListPointer(
            rawBuffer.assumingMemoryBound(to: AudioBufferList.self)
        )
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeUnretainedValue() as String
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        stringProperty(deviceID, selector: kAudioObjectPropertyName)
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafeMutablePointer(to: &deviceID) { pointer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}

private enum LocalModelState: Equatable {
    case missing
    case downloading(Int)
    case loading
    case ready
    case failed(String)
}

@MainActor
private final class LocalTranscriber {
    private(set) var state: LocalModelState = .missing
    private var manager: AsrManager?
    var onStateChange: (() -> Void)?

    var isDownloaded: Bool {
        AsrModels.modelsExist(
            at: AsrModels.defaultCacheDirectory(for: .v2),
            version: .v2
        )
    }

    func loadCachedModel() async {
        guard isDownloaded else {
            setState(.missing)
            return
        }
        await prepare(download: false)
    }

    func downloadModel() async {
        await prepare(download: true)
    }

    func transcribe(_ url: URL) async throws -> String {
        guard let manager else { throw BetterVoiceError.localModelUnavailable }
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(url, decoderState: &decoderState).text
    }

    private func prepare(download: Bool) async {
        guard state != .loading, !isDownloading else { return }
        setState(download ? .downloading(0) : .loading)
        do {
            let progress: ProgressHandler?
            if download {
                progress = { [weak self] update in
                    Task { @MainActor in
                        self?.setState(.downloading(Int(update.fractionCompleted * 100)))
                    }
                }
            } else {
                progress = nil
            }
            let models = download
                ? try await AsrModels.downloadAndLoad(version: .v2, progressHandler: progress)
                : try await AsrModels.loadFromCache(version: .v2)
            manager = AsrManager(config: .default, models: models)
            setState(.ready)
        } catch {
            manager = nil
            setState(.failed(error.localizedDescription))
        }
    }

    private var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    private func setState(_ value: LocalModelState) {
        state = value
        onStateChange?()
    }
}

private final class AudioRecorder {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    var onLevel: (@MainActor @Sendable (Float) -> Void)?

    func start(device: MicrophoneDevice) throws {
        precondition(engine == nil)
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            throw BetterVoiceError.microphoneRoutingFailed(device.name, -1)
        }

        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw BetterVoiceError.microphoneRoutingFailed(device.name, status)
        }

        let format = inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw BetterVoiceError.microphoneUnavailable }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BetterVoice-(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let levelHandler = onLevel

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            try? file.write(from: buffer)
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) {
                sum += samples[index] * samples[index]
            }
            let level = min(1, sqrt(sum / Float(buffer.frameLength)) * 12)
            Task { @MainActor in levelHandler?(level) }
        }

        do {
            engine.prepare()
            try engine.start()
            self.engine = engine
            audioFile = file
            recordingURL = url
        } catch {
            inputNode.removeTap(onBus: 0)
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func stop() throws -> URL {
        guard let engine, let recordingURL else { throw BetterVoiceError.sessionUnavailable }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        audioFile = nil
        self.recordingURL = nil
        return recordingURL
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
    private let trailLifetime: TimeInterval = 0.55
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
        context.clear(bounds)
        let now = ProcessInfo.processInfo.systemUptime

        context.setLineCap(.round)
        let segments = trailSegments(
            points: trail.map(\.point),
            times: trail.map(\.time)
        )
        for segment in segments {
            let previous = trail[segment.from]
            let current = trail[segment.to]
            let age = max(0, now - current.time)
            let fade = max(0, 1 - age / trailLifetime)
            guard fade > 0 else { continue }
            context.move(to: localPoint(previous.point))
            context.addLine(to: localPoint(current.point))
            context.setStrokeColor(NSColor.systemCyan.withAlphaComponent(0.2 * fade).cgColor)
            context.setLineWidth(9)
            context.strokePath()

            context.move(to: localPoint(previous.point))
            context.addLine(to: localPoint(current.point))
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.92 * fade).cgColor)
            context.setLineWidth(3.5)
            context.strokePath()
        }

        if let head = trail.last {
            let age = max(0, now - head.time)
            let fade = max(0, 1 - age / trailLifetime)
            if fade > 0 {
                let center = localPoint(head.point)
                context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.24 * fade).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18))
                context.setFillColor(NSColor.systemCyan.withAlphaComponent(0.98 * fade).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
            }
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
private final class RecordingHUDView: NSView {
    var microphone = ""
    var level: Float = 0
    var contextCount = 0
    var isFinishing = false
    var reduceMotion = false

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.07, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18).fill()

        let phase = reduceMotion ? 0 : Int(ProcessInfo.processInfo.systemUptime * 10)
        let shape: [CGFloat] = [0.45, 0.75, 1, 0.7, 0.4]
        for index in shape.indices {
            let pulse = CGFloat((phase + index) % 5) * 0.35
            let height = 7 + shape[index] * CGFloat(level) * 20 + pulse
            let rect = NSRect(x: 18 + CGFloat(index) * 7, y: 28 - height / 2, width: 3.5, height: height)
            NSColor.systemBlue.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }

        let title = isFinishing ? "Transcribing…" : "Listening"
        let detail = contextCount > 0 ? "(microphone)  •  (contextCount) captured" : microphone
        (title as NSString).draw(
            at: NSPoint(x: 62, y: 10),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
        )
        (detail as NSString).draw(
            at: NSPoint(x: 62, y: 30),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 1)
            ]
        )
    }
}

@MainActor
private final class RecordingHUDController {
    private let view = RecordingHUDView(frame: NSRect(x: 0, y: 0, width: 290, height: 56))
    private var panel: NSPanel?
    private var timer: Timer?

    func show(microphone: String) {
        hide()
        view.microphone = microphone
        view.level = 0
        view.contextCount = 0
        view.isFinishing = false
        view.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel("BetterVoice listening on (microphone)")

        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let panelFrame = NSRect(
            x: frame.midX - view.frame.width / 2,
            y: frame.minY + 24,
            width: view.frame.width,
            height: view.frame.height
        )
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = view
        self.panel = panel
        panel.orderFrontRegardless()

        guard !view.reduceMotion else { return }
        let timer = Timer(timeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.view.needsDisplay = true }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(level: Float) {
        view.level = max(level, view.level * 0.78)
        view.needsDisplay = true
    }

    func setContextCount(_ count: Int) {
        view.contextCount = count
        view.needsDisplay = true
    }

    func showFinishing() {
        view.isFinishing = true
        view.level = 0.2
        view.setAccessibilityLabel("BetterVoice transcribing")
        view.needsDisplay = true
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
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
        let clipboardCopied = Clipboard.copy(transcript: trimmed, images: images)
        print(trimmed)
        return (markdownURL, clipboardCopied)
    }
}

@MainActor
private enum Clipboard {
    static func copy(transcript: String, images: [URL]) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let textItem = NSPasteboardItem()
        let rich = NSMutableAttributedString(string: transcript + (images.isEmpty ? "" : "\n\n"))
        var imageItems: [NSPasteboardItem] = []
        for (index, imageURL) in images.enumerated() {
            guard let data = try? Data(contentsOf: imageURL), let image = NSImage(data: data) else {
                return false
            }
            let attachment = NSTextAttachment()
            attachment.image = image
            rich.append(NSAttributedString(attachment: attachment))
            rich.append(NSAttributedString(string: "\nContext \(index + 1)\n\n"))

            let imageItem = NSPasteboardItem()
            guard imageItem.setData(data, forType: .png) else { return false }
            if let tiff = image.tiffRepresentation { imageItem.setData(tiff, forType: .tiff) }
            imageItems.append(imageItem)
        }

        var objects: [NSPasteboardWriting] = imageItems
        if !transcript.isEmpty {
            guard textItem.setString(transcript, forType: .string) else { return false }
            if let rtf = try? rich.data(
                from: NSRange(location: 0, length: rich.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                textItem.setData(rtf, forType: .rtf)
            }
            objects.insert(textItem, at: 0)
        }
        return !objects.isEmpty && pasteboard.writeObjects(objects)
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
private final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let microphones = MicrophoneManager()
    private let recorder = AudioRecorder()
    private let transcriber = LocalTranscriber()
    private let trailOverlay = TrailOverlayController()
    private let recordingHUD = RecordingHUDController()
    private var inputMonitor: InputMonitor?
    private var detector = CircleGestureDetector()
    private var output: SessionOutput?
    private var transcript = ""
    private var state = SessionState.idle
    private var statusMenuItem: NSMenuItem?
    private var recordingMenuItem: NSMenuItem?
    private var modelMenuItem: NSMenuItem?
    private var microphoneMenu: NSMenu?
    private var statusAnimationTimer: Timer?
    private var statusFeedbackTimer: Timer?
    private var statusPulse = false
    private var reduceMotion = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        microphones.refresh()
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        setStatusIcon(.idle)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = "BetterVoice — hold ⌘⌥ to record • Microphone: \(microphones.selectedLabel)"

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

        let modelItem = NSMenuItem(title: "Download Local Model (~500 MB)", action: #selector(downloadModel), keyEquivalent: "")
        modelItem.target = self
        modelMenuItem = modelItem
        menu.addItem(modelItem)

        let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let microphoneMenu = NSMenu()
        microphoneItem.submenu = microphoneMenu
        self.microphoneMenu = microphoneMenu
        menu.addItem(microphoneItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit BetterVoice", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.delegate = self
        statusItem.menu = menu
        refreshMicrophoneMenu()
        refreshModelMenu()

        transcriber.onStateChange = { [weak self] in self?.refreshModelMenu() }
        recorder.onLevel = { [weak self] level in self?.recordingHUD.update(level: level) }
        Task { await transcriber.loadCachedModel() }

        inputMonitor = InputMonitor(
            toggle: { [weak self] in self?.toggleRecording() },
            mouseMoved: { [weak self] quartzPoint in
                self?.handleMouse(quartzPoint: quartzPoint)
            }
        )
        inputMonitor?.start()
        requestMicrophoneAuthorization()
        requestSystemPermissions()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard let statusMenu = statusItem.menu, menu === statusMenu else { return }
        microphones.refresh()
        refreshMicrophoneMenu()
    }

    private func refreshMicrophoneMenu() {
        guard let microphoneMenu else { return }
        microphoneMenu.removeAllItems()
        let enabled = state == .idle

        let systemDefault = NSMenuItem(
            title: "System Default — \(microphones.systemDefaultName)",
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        systemDefault.target = self
        systemDefault.state = microphones.selectedUID == nil ? .on : .off
        systemDefault.isEnabled = enabled
        microphoneMenu.addItem(systemDefault)

        if !microphones.devices.isEmpty {
            microphoneMenu.addItem(.separator())
            for device in microphones.devices {
                let item = NSMenuItem(title: device.name, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.uid
                item.state = microphones.selectedUID == device.uid ? .on : .off
                item.isEnabled = enabled
                microphoneMenu.addItem(item)
            }
        } else {
            let unavailable = NSMenuItem(title: "No input microphones found", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            microphoneMenu.addItem(unavailable)
        }

        if microphones.selectionUnavailable {
            let unavailable = NSMenuItem(title: "Selected microphone is unavailable", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            microphoneMenu.addItem(.separator())
            microphoneMenu.addItem(unavailable)
        }
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard state == .idle else { return }
        microphones.select(uid: sender.representedObject as? String)
        refreshMicrophoneMenu()
        showStatus("Microphone: \(microphones.selectedLabel)", resetAfter: 3)
    }

    private func refreshModelMenu() {
        guard let modelMenuItem else { return }
        switch transcriber.state {
        case .missing:
            modelMenuItem.title = "Download Local Model (~500 MB)"
            modelMenuItem.isEnabled = state == .idle
        case .downloading(let percent):
            modelMenuItem.title = "Downloading Local Model… \(percent)%"
            modelMenuItem.isEnabled = false
        case .loading:
            modelMenuItem.title = "Loading Local Model…"
            modelMenuItem.isEnabled = false
        case .ready:
            modelMenuItem.title = "Local Parakeet Model Ready"
            modelMenuItem.isEnabled = false
        case .failed:
            modelMenuItem.title = "Retry Local Model Download"
            modelMenuItem.isEnabled = state == .idle
        }
        if state == .idle {
            recordingMenuItem?.isEnabled = transcriber.state == .ready
        }
    }

    @objc private func downloadModel() {
        guard state == .idle else { return }
        showStatus("Downloading local model…")
        Task {
            await transcriber.downloadModel()
            switch transcriber.state {
            case .ready:
                showStatus("Local model ready • hold ⌘⌥ to record", resetAfter: 4)
            case .failed(let message):
                showError("Model download failed: \(message)")
            default:
                break
            }
        }
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
            guard transcriber.state == .ready else { throw BetterVoiceError.localModelUnavailable }
            microphones.refresh()
            guard !microphones.selectionUnavailable else {
                throw BetterVoiceError.microphoneSelectionUnavailable(microphones.selectedLabel)
            }
            guard let selectedMicrophone = microphones.recordingDevice else {
                throw BetterVoiceError.microphoneUnavailable
            }
            output = try SessionOutput()
            detector.reset()
            transcript = ""
            try recorder.start(device: selectedMicrophone)
            state = .recording
            refreshMicrophoneMenu()
            refreshModelMenu()
            trailOverlay.start()
            recordingHUD.show(microphone: selectedMicrophone.name)
            setStatusIcon(.recording)
            showStatus("Recording • Microphone: \(selectedMicrophone.name)")
            updateMenuTitle("Stop recording (⌘⌥)", enabled: true)
        } catch {
            output = nil
            showError(error.localizedDescription)
        }
    }

    private func stopRecording() {
        guard state == .recording else { return }
        state = .finishing
        refreshMicrophoneMenu()
        trailOverlay.stop()
        recordingHUD.showFinishing()
        setStatusIcon(.finishing)
        showStatus("Finishing…")
        updateMenuTitle("Finishing… (⌘⌥)", enabled: false)
        do {
            let audioURL = try recorder.stop()
            Task {
                defer { try? FileManager.default.removeItem(at: audioURL) }
                do {
                    transcript = try await transcriber.transcribe(audioURL)
                    finishSession()
                } catch {
                    finishSession(transcriptionError: error)
                }
            }
        } catch {
            finishSession(transcriptionError: error)
        }
    }

    private func finishSession(transcriptionError: Error? = nil) {
        let session = output
        let hadTranscript = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        do {
            guard let session else { throw BetterVoiceError.sessionUnavailable }
            let result = try session.finish(transcript: transcript)
            let hasContext = !session.images.isEmpty
            output = nil
            state = .idle
            recordingHUD.hide()
            refreshMicrophoneMenu()
            refreshModelMenu()
            setStatusIcon(.idle)
            updateMenuTitle("Start recording (⌘⌥)", enabled: true)

            if let transcriptionError {
                let delivery = result.clipboardCopied
                    ? (hasContext ? "Screen context copied." : "Session saved.")
                    : "Session saved; clipboard text fallback used."
                showError("Transcription failed: \(transcriptionError.localizedDescription) \(delivery)")
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
            recordingHUD.hide()
            refreshMicrophoneMenu()
            refreshModelMenu()
            setStatusIcon(.idle)
            updateMenuTitle("Start recording (⌘⌥)", enabled: true)
            if let transcriptionError {
                showError("Transcription failed: \(transcriptionError.localizedDescription); session save failed: \(error.localizedDescription)")
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
            recordingHUD.setContextCount(output.images.count)
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
        recordingMenuItem?.isEnabled = enabled && (state != .idle || transcriber.state == .ready)
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
        recordingHUD.hide()
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
