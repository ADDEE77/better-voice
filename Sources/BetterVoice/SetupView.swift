import AppKit
import BetterVoiceCore
import SwiftUI

struct SetupMicrophoneOption: Identifiable, Equatable {
    let id: String
    let name: String
}

struct HotkeyBinding: Equatable, Sendable {
    let keyCode: UInt16?
    let command: Bool
    let option: Bool
    let control: Bool
    let shift: Bool
    let keyName: String

    static let option = HotkeyBinding(
        keyCode: nil,
        command: false,
        option: true,
        control: false,
        shift: false,
        keyName: ""
    )

    static let commandOption = HotkeyBinding(
        keyCode: nil,
        command: true,
        option: true,
        control: false,
        shift: false,
        keyName: ""
    )

    var label: String {
        let modifiers = [
            command ? "⌘" : "",
            option ? "⌥" : "",
            control ? "⌃" : "",
            shift ? "⇧" : ""
        ].joined()
        return modifiers + keyName
    }

    func matches(command: Bool, option: Bool, control: Bool, shift: Bool) -> Bool {
        self.command == command
            && self.option == option
            && self.control == control
            && self.shift == shift
    }
}

struct HotkeyConfiguration: Equatable, Sendable {
    var quick: HotkeyBinding
    var long: HotkeyBinding

    static let standard = HotkeyConfiguration(
        quick: .option,
        long: .commandOption
    )
}

@MainActor
final class SetupModel: ObservableObject {
    @Published var microphoneGranted = false
    @Published var screenGranted = false
    @Published var accessibilityGranted = false
    @Published var microphoneName = "Checking…"
    @Published var microphoneOptions: [SetupMicrophoneOption] = []
    @Published var selectedMicrophoneID = "automatic"
    @Published var microphoneSelectionEnabled = true
    @Published var modelStatus = "Checking…"
    @Published var modelReady = false
    @Published var modelBusy = false
    @Published var grammarCorrectionEnabled = false
    @Published var grammarStatus = "Download on first use (~36 MB)"
    @Published var grammarReady = false
    @Published var grammarBusy = false
    @Published var developerCleanupEnabled = true
    @Published var grammarSelectionEnabled = true
    @Published var transcriptionLanguage = TranscriptionLanguage.english
    @Published var languageSelectionEnabled = true
    @Published var circleMinimumAngleDegrees = 340.0
    @Published var hotkeyConfiguration = HotkeyConfiguration.standard
    @Published var hotkeyError: String?

    var requestMicrophone: () -> Void = {}
    var chooseMicrophone: (String) -> Void = { _ in }
    var requestScreen: () -> Void = {}
    var requestAccessibility: () -> Void = {}
    var downloadModel: () -> Void = {}
    var downloadGrammarModel: () -> Void = {}
    var setGrammarCorrection: (Bool) -> Void = { _ in }
    var setDeveloperCleanup: (Bool) -> Void = { _ in }
    var setTranscriptionLanguage: (TranscriptionLanguage) -> Void = { _ in }
    var setCircleMinimumAngle: (Double) -> Void = { _ in }
    var setHotkeyConfiguration: (HotkeyConfiguration) -> Void = { _ in }
    var refresh: () -> Void = {}
    var complete: () -> Void = {}

    var readyCount: Int {
        [microphoneGranted, screenGranted, accessibilityGranted, modelReady].filter { $0 }.count
    }

    var setupComplete: Bool {
        readyCount == 4
    }
}

private enum SetupSection: String, CaseIterable, Identifiable {
    case overview
    case dictation
    case visualContext
    case shortcuts
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .dictation: return "Dictation"
        case .visualContext: return "Visual context"
        case .shortcuts: return "Shortcuts"
        case .storage: return "Storage"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "Your recording setup at a glance."
        case .dictation: return "Microphone, language, and local models."
        case .visualContext: return "Screen capture and circle detection."
        case .shortcuts: return "Choose how BetterVoice starts and stops."
        case .storage: return "Saved sessions and local data."
        }
    }

    var icon: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .dictation: return "waveform"
        case .visualContext: return "scope"
        case .shortcuts: return "command"
        case .storage: return "internaldrive"
        }
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    @State private var selection: SetupSection = .overview

    private enum Links {
        static let guide = URL(string: "https://github.com/TarunTomar122/better-voice#use-it")!
        static let contributing = URL(string: "https://github.com/TarunTomar122/better-voice/blob/main/CONTRIBUTING.md")!
        static let issues = URL(string: "https://github.com/TarunTomar122/better-voice/issues")!
    }

    var body: some View {
        HStack(spacing: 0) {
            SetupSidebar(selection: $selection)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selection.title)
                                .font(.title2.weight(.semibold))
                            Text(selection.subtitle)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Done") { model.complete() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                    sectionContent
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, idealWidth: 980, minHeight: 620, idealHeight: 700)
        .onAppear { model.refresh() }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        case .overview:
            overview
        case .dictation:
            dictation
        case .visualContext:
            visualContext
        case .shortcuts:
            shortcuts
        case .storage:
            storage
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("BetterVoice", systemImage: "waveform.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                    Text("Talk. Point. Give your agent the whole thought.")
                        .font(.title3)
                    Text("Speak normally, circle anything important, and BetterVoice keeps the words and full-screen visual context together.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                CapturePreview()
                    .frame(width: 220, height: 132)
            }
            ReadinessCard(model: model)
            HStack(spacing: 10) {
                Link(destination: Links.guide) {
                    Label("Read the guide", systemImage: "book")
                }
                .buttonStyle(.bordered)
                Link(destination: Links.contributing) {
                    Label("Start contributing", systemImage: "hammer")
                }
                .buttonStyle(.borderedProminent)
                Link(destination: Links.issues) {
                    Label("Report a problem", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 28) {
                ShortcutGuide(keys: model.hotkeyConfiguration.quick.label, title: "Quick note", detail: "Hold to record. Release to finish.")
                ShortcutGuide(keys: model.hotkeyConfiguration.long.label, title: "Long explanation", detail: "Press once to start, again to finish.")
            }
        }
    }

    private var dictation: some View {
        VStack(alignment: .leading, spacing: 16) {
            MicrophoneSetupRow(model: model)
            SetupRow(
                title: "Accessibility",
                detail: model.accessibilityGranted ? "Shortcuts and transcript insertion are ready" : "Needed for global shortcuts and returning text",
                ready: model.accessibilityGranted,
                action: model.requestAccessibility
            )
            SetupRow(
                title: "Local transcription model",
                detail: model.modelStatus,
                ready: model.modelReady,
                busy: model.modelBusy,
                action: model.downloadModel
            )
            LanguageSetupRow(model: model)
            GrammarSetupRow(
                title: "Grammar cleanup (Beta)",
                detail: "t5-tiny-gec-hone runs locally after transcription to fix punctuation and sentence structure. It falls back to the raw transcript if unavailable.",
                status: model.transcriptionLanguage.allowsGrammarCorrection
                    ? model.grammarStatus
                    : "English only. Skipped while dictating \(model.transcriptionLanguage.name).",
                ready: model.grammarReady && model.transcriptionLanguage.allowsGrammarCorrection,
                busy: model.grammarBusy,
                selectionEnabled: model.grammarSelectionEnabled
                    && model.transcriptionLanguage.allowsGrammarCorrection,
                download: model.downloadGrammarModel,
                isEnabled: Binding(
                    get: { model.grammarCorrectionEnabled },
                    set: {
                        model.grammarCorrectionEnabled = $0
                        model.setGrammarCorrection($0)
                    }
                )
            )
            GrammarSetupRow(
                title: "Developer vocabulary (Beta)",
                detail: "A fast local pass for technical terms such as npm, GitHub, SwiftUI, API, and JSON. No extra model download.",
                status: "Preserves your wording and adapts acronyms for developer apps.",
                ready: true,
                busy: false,
                selectionEnabled: model.grammarSelectionEnabled,
                download: {},
                toggleAccessibilityLabel: "Enable developer vocabulary beta",
                isEnabled: Binding(
                    get: { model.developerCleanupEnabled },
                    set: {
                        model.developerCleanupEnabled = $0
                        model.setDeveloperCleanup($0)
                    }
                )
            )
        }
    }

    private var visualContext: some View {
        VStack(alignment: .leading, spacing: 20) {
            SetupRow(
                title: "Screen Recording",
                detail: model.screenGranted ? "Ready to capture circles" : "Needed only when you circle the screen",
                ready: model.screenGranted,
                action: model.requestScreen
            )
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Circle detection", systemImage: "scope")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(model.circleMinimumAngleDegrees.rounded()))°")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("Set how much of a circle BetterVoice needs before it captures the screen. Higher values reduce accidental captures.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text("300°").font(.caption).foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { model.circleMinimumAngleDegrees },
                            set: {
                                model.circleMinimumAngleDegrees = $0
                                model.setCircleMinimumAngle($0)
                            }
                        ),
                        in: 300...359,
                        step: 1
                    )
                    Text("359°").font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Minimum circle angle")
                Button("Use 340° default") {
                    model.circleMinimumAngleDegrees = 340
                    model.setCircleMinimumAngle(340)
                }
                .buttonStyle(.link)
                .font(.callout)
            }
            .padding(16)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("These are global modifier shortcuts. They work while BetterVoice is in the menu bar and can be changed any time while idle.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HotkeyRecordingRow(
                title: "Quick note",
                detail: "Hold this shortcut to record. Release it to finish.",
                binding: Binding(
                    get: { model.hotkeyConfiguration.quick },
                    set: { value in updateHotkeys(quick: value) }
                )
            )
            HotkeyRecordingRow(
                title: "Long explanation",
                detail: "Press this shortcut once to start and again to finish.",
                binding: Binding(
                    get: { model.hotkeyConfiguration.long },
                    set: { value in updateHotkeys(long: value) }
                )
            )
            if let hotkeyError = model.hotkeyError {
                Label(hotkeyError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                Text("Click the current shortcut, press a combination, then click Done. The new shortcut is shown immediately and never types into your app while you set it.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Button("Reset shortcuts to defaults") {
                let defaults = HotkeyConfiguration.standard
                model.hotkeyError = nil
                model.hotkeyConfiguration = defaults
                model.setHotkeyConfiguration(defaults)
            }
            .buttonStyle(.link)
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Local by default", systemImage: "lock.shield")
                .font(.headline)
            Text("Transcripts, audio cleanup, and captured images stay on this Mac. BetterVoice stores sessions in Desktop/BetterVoice for up to 7 days and caps the folder at 500 MB.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Label("Saved sessions", systemImage: "folder")
                .font(.headline)
            Text("Use Recent in the menu bar to copy the latest transcript or images, or open Saved Sessions to browse the local folders.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: Links.guide) {
                Label("Read storage details in the guide", systemImage: "book")
            }
            .buttonStyle(.bordered)
        }
    }

    private func updateHotkeys(quick: HotkeyBinding? = nil, long: HotkeyBinding? = nil) {
        var configuration = model.hotkeyConfiguration
        if let quick { configuration.quick = quick }
        if let long { configuration.long = long }
        guard configuration.quick != configuration.long else {
            model.hotkeyError = "Quick note and long explanation need different shortcuts."
            return
        }
        model.hotkeyError = nil
        model.hotkeyConfiguration = configuration
        model.setHotkeyConfiguration(configuration)
    }
}

private struct SetupSidebar: View {
    @Binding var selection: SetupSection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 8)
            VStack(spacing: 4) {
                ForEach(SetupSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == section ? .primary : .secondary)
                    .background(
                        selection == section
                            ? Color.accentColor.opacity(0.16)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: 198)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ReadinessCard: View {
    @ObservedObject var model: SetupModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.setupComplete ? "checkmark.seal.fill" : "sparkles")
                .font(.title2)
                .foregroundStyle(model.setupComplete ? Color.green : Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.setupComplete ? "Ready to record" : "Finish setup to get started")
                    .fontWeight(.semibold)
                Text(model.setupComplete
                     ? "Use \(model.hotkeyConfiguration.quick.label) for a quick note or \(model.hotkeyConfiguration.long.label) for a longer explanation."
                     : "\(model.readyCount) of 4 essentials are ready. You can return here any time from the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressView(value: Double(model.readyCount), total: 4)
                .frame(width: 110)
                .accessibilityLabel("Setup progress")
        }
        .padding(16)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HotkeyRecordingRow: View {
    let title: String
    let detail: String
    @Binding var binding: HotkeyBinding
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 14) {
            Text(binding.label.isEmpty ? "⌁" : binding.label)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .frame(width: 48, height: 42)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(isRecording ? "Listening…" : binding.label) {
                isRecording = true
            }
            .controlSize(.small)
            .accessibilityLabel(isRecording ? "Listening for \(title) shortcut" : "Change \(title) shortcut, currently \(binding.label)")
            HotkeyCaptureView(isRecording: $isRecording) { captured in
                isRecording = false
                binding = captured
            }
            .frame(width: 1, height: 1)
        }
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (HotkeyBinding) -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onCapture = onCapture
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class HotkeyCaptureNSView: NSView {
    var isRecording = false
    var onCapture: ((HotkeyBinding) -> Void)?
    private var pendingModifierBinding: HotkeyBinding?
    private var captureWorkItem: DispatchWorkItem?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        captureWorkItem?.cancel()
        pendingModifierBinding = nil
        onCapture?(HotkeyBinding(
            keyCode: event.keyCode,
            command: event.modifierFlags.contains(.command),
            option: event.modifierFlags.contains(.option),
            control: event.modifierFlags.contains(.control),
            shift: event.modifierFlags.contains(.shift),
            keyName: keyName(for: event)
        ))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording, Self.modifierKeyCodes.contains(event.keyCode) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command)
                || flags.contains(.option)
                || flags.contains(.control)
                || flags.contains(.shift) else { return }
        pendingModifierBinding = HotkeyBinding(
            keyCode: nil,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            keyName: ""
        )
        captureWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRecording, let binding = self.pendingModifierBinding else { return }
            self.onCapture?(binding)
        }
        captureWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]

    private func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}

private struct MicrophoneSetupRow: View {
    @ObservedObject var model: SetupModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.microphoneGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(model.microphoneGranted ? Color.green : Color.secondary)
                .font(.title3)
                .accessibilityLabel(model.microphoneGranted ? "Ready" : "Needs setup")
            VStack(alignment: .leading, spacing: 2) {
                Text("Microphone").fontWeight(.medium)
                Text(model.microphoneGranted ? model.microphoneName : "Needed to record your voice")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.microphoneGranted && !model.microphoneOptions.isEmpty {
                Picker("Microphone", selection: Binding(
                    get: { model.selectedMicrophoneID },
                    set: { model.chooseMicrophone($0) }
                )) {
                    ForEach(model.microphoneOptions) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                .disabled(!model.microphoneSelectionEnabled)
                .accessibilityLabel("Microphone input")
            } else if !model.microphoneGranted {
                Button("Set Up", action: model.requestMicrophone)
            } else {
                Text("No inputs found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LanguageSetupRow: View {
    @ObservedObject var model: SetupModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(Color.secondary)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dictation language").fontWeight(.medium)
                Text(model.transcriptionLanguage.usesEnglishOnlyModel
                     ? "English uses the model you already downloaded."
                     : "Other languages use the multilingual model, a separate one-time download.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Picker("Dictation language", selection: Binding(
                get: { model.transcriptionLanguage },
                set: {
                    model.transcriptionLanguage = $0
                    model.setTranscriptionLanguage($0)
                }
            )) {
                ForEach(TranscriptionLanguage.all, id: \.self) { language in
                    Text(language.name).tag(language)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)
            .disabled(!model.languageSelectionEnabled)
            .accessibilityLabel("Dictation language")
        }
    }
}

private struct ShortcutGuide: View {
    let keys: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .frame(minWidth: 52)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SetupRow: View {
    let title: String
    let detail: String
    let ready: Bool
    var busy = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ready ? Color.green : Color.secondary)
                .font(.title3)
                .accessibilityLabel(ready ? "Ready" : "Needs setup")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if busy {
                ProgressView().controlSize(.small)
            } else if !ready {
                Button("Set Up", action: action)
            }
        }
    }
}

private struct GrammarSetupRow: View {
    let title: String
    let detail: String
    let status: String
    let ready: Bool
    let busy: Bool
    let selectionEnabled: Bool
    let download: () -> Void
    var toggleAccessibilityLabel = "Enable grammar cleanup beta"
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.badge.checkmark")
                .foregroundStyle(.blue)
                .font(.title3)
                .accessibilityLabel("Information")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 7) {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .accessibilityLabel(toggleAccessibilityLabel)
                    .disabled(!selectionEnabled)
                if busy {
                    ProgressView().controlSize(.small)
                } else if !ready {
                    Button("Download", action: download)
                        .controlSize(.small)
                        .disabled(!selectionEnabled)
                }
            }
        }
    }
}

private struct CapturePreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
            VStack(spacing: 9) {
                HStack(spacing: 5) {
                    Circle().fill(.red.opacity(0.7)).frame(width: 7)
                    Circle().fill(.yellow.opacity(0.7)).frame(width: 7)
                    Circle().fill(.green.opacity(0.7)).frame(width: 7)
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(.secondary.opacity(0.22)).frame(width: 110, height: 8)
                        Capsule().fill(.secondary.opacity(0.15)).frame(width: 86, height: 8)
                        RoundedRectangle(cornerRadius: 6).fill(.blue.opacity(0.16)).frame(width: 72, height: 28)
                    }
                    Spacer()
                }
            }
            .padding(15)
            Circle()
                .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [44, 7]))
                .frame(width: 92, height: 72)
                .rotationEffect(.degrees(-16))
                .offset(x: 39, y: 25)
            Circle()
                .fill(.blue.opacity(0.14))
                .frame(width: 78, height: 60)
                .offset(x: 39, y: 25)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A blue mouse trail circles a button and captures the screen")
    }
}

@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: SetupModel) {
        if let window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: SetupView(model: model)))
        window.title = "BetterVoice Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 620)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

@MainActor
final class RecoveryNoticeModel: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
    @Published var actionTitle = "Open Setup"
    var action: () -> Void = {}
}

private struct RecoveryNoticeView: View {
    @ObservedObject var model: RecoveryNoticeModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.title).fontWeight(.semibold)
                Text(model.detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Button(model.actionTitle, action: model.action)
        }
        .padding(18)
        .frame(width: 540)
    }
}

@MainActor
final class RecoveryNoticeController: NSObject, NSWindowDelegate {
    let model = RecoveryNoticeModel()
    private var window: NSWindow?

    func show(title: String, detail: String, actionTitle: String, action: @escaping () -> Void) {
        model.title = title
        model.detail = detail
        model.actionTitle = actionTitle
        model.action = { [weak self] in
            self?.window?.close()
            action()
        }
        if window == nil {
            let panel = NSPanel(contentViewController: NSHostingController(rootView: RecoveryNoticeView(model: model)))
            panel.title = "BetterVoice"
            panel.styleMask = [.titled, .closable, .utilityWindow]
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.delegate = self
            panel.center()
            window = panel
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
