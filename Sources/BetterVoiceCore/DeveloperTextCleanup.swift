import Foundation

public enum DeveloperAppProfile: String, Sendable {
    case general
    case terminal
    case editor
    case ai

    public static func infer(bundleIdentifier: String?, applicationName: String?) -> Self {
        let identifier = bundleIdentifier?.lowercased()
        let name = applicationName?.lowercased()
        let terminalNames = ["terminal", "iterm2", "ghostty", "warp", "kitty", "wezterm"]
        let editorNames = ["xcode", "visual studio code", "cursor", "windsurf", "neovim"]
        let aiNames = ["chatgpt", "claude", "codex"]
        if name.map(terminalNames.contains) == true || identifier.map({ [
            "com.apple.terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty"
        ].contains($0) }) == true {
            return .terminal
        }
        if name.map(editorNames.contains) == true || identifier.map({ ["com.apple.dt.xcode", "com.microsoft.vscode"].contains($0) }) == true {
            return .editor
        }
        if name.map(aiNames.contains) == true {
            return .ai
        }
        return .general
    }
}

/// A conservative, zero-download pass for terms that speech models commonly mis-case.
public enum DeveloperTextCleanup {
    private static let terms: [(String, String)] = [
        ("javascript", "JavaScript"), ("typescript", "TypeScript"), ("swiftui", "SwiftUI"),
        ("nextjs", "Next.js"), ("next.js", "Next.js"), ("postgresql", "PostgreSQL"),
        ("postgres", "Postgres"), ("mongodb", "MongoDB"), ("supabase", "Supabase"),
        ("graphql", "GraphQL"), ("github", "GitHub"), ("gitlab", "GitLab"), ("bitbucket", "Bitbucket"),
        ("macos", "macOS"), ("ios", "iOS"), ("ipados", "iPadOS"), ("watchos", "watchOS"),
        ("xcode", "Xcode"), ("appkit", "AppKit"), ("coregraphics", "CoreGraphics"),
        ("avfoundation", "AVFoundation"), ("openai", "OpenAI"), ("chatgpt", "ChatGPT"),
        ("pytorch", "PyTorch"), ("tensorflow", "TensorFlow"), ("onnx", "ONNX"),
        ("parakeet", "Parakeet"), ("whisper", "Whisper"), ("fluid audio", "FluidAudio"),
        ("api", "API"), ("sdk", "SDK"), ("cli", "CLI"), ("ide", "IDE"), ("orm", "ORM"),
        ("cdn", "CDN"), ("dns", "DNS"), ("ssl", "SSL"), ("tls", "TLS"), ("ssh", "SSH"),
        ("html", "HTML"), ("css", "CSS"), ("xml", "XML"), ("sql", "SQL"), ("jwt", "JWT"),
        ("csv", "CSV"), ("pdf", "PDF"), ("svg", "SVG"), ("png", "PNG"), ("json", "JSON"),
        ("yaml", "YAML"), ("toml", "TOML"), ("uuid", "UUID"), ("http", "HTTP"), ("https", "HTTPS"),
        ("cors", "CORS"), ("crud", "CRUD"), ("rest", "REST"), ("grpc", "gRPC"),
        ("tcp", "TCP"), ("udp", "UDP"), ("vpn", "VPN"), ("cpu", "CPU"), ("gpu", "GPU"),
        ("npm", "npm"), ("npx", "npx"), ("aws", "AWS"), ("gcp", "GCP"), ("ec2", "EC2"),
        ("s3", "S3"), ("llm", "LLM"), ("gpt", "GPT"), ("rag", "RAG"), ("nlp", "NLP"),
        ("mps", "MPS"), ("ai", "AI")
    ]

    private static let spokenAcronyms: [(String, String)] = [
        ("n p m", "npm"), ("n p x", "npx"), ("g i t h u b", "GitHub"),
        ("j s o n", "JSON"), ("a p i", "API"), ("c l i", "CLI"), ("s d k", "SDK")
    ]

    private static let ambiguousTerms: Set<String> = ["rest", "rag", "crud", "whisper", "parakeet", "ai"]

    /// - Parameter overrides: the user's own corrections, from `VocabularyFile`.
    ///   They run before the built-in table and in the order given, so a caller can
    ///   put longer phrases first, and a source listed here replaces the built-in
    ///   spelling for that same source instead of fighting it.
    public static func apply(
        _ text: String,
        profile: DeveloperAppProfile = .general,
        overrides: [(String, String)] = []
    ) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        if profile == .terminal || profile == .editor || profile == .ai {
            for (source, replacement) in spokenAcronyms {
                result = replaceWholePhrase(source, with: replacement, in: result)
            }
        }
        for (source, replacement) in overrides {
            result = replaceWholePhrase(source, with: replacement, in: result)
        }
        let overridden = Set(overrides.map { $0.0.lowercased() })
        for (source, replacement) in terms {
            guard profile != .general || !ambiguousTerms.contains(source) else { continue }
            guard !overridden.contains(source) else { continue }
            result = replaceWholePhrase(source, with: replacement, in: result)
        }
        return result
    }

    /// Characters that continue a word. The accented Latin ranges belong here:
    /// without them an accented letter reads as a separator, so `api` matches as a
    /// whole word inside `apiário` and the pass rewrites ordinary prose.
    ///
    /// The combining marks cover the same letters in decomposed form, where the
    /// accent is its own scalar. Without that range `ide` matches inside a
    /// decomposed `idéia`, since the scalar after `ide` is the accent rather than
    /// the letter it belongs to. Widening the boundary is preferred over
    /// normalizing the input, which would hand the user back text in a different
    /// form than the one they dictated into.
    private static let wordCharacters =
        "A-Za-z0-9_./\\-"
        + "\u{00C0}-\u{00D6}\u{00D8}-\u{00F6}\u{00F8}-\u{00FF}"
        + "\u{0300}-\u{036F}"

    private static func replaceWholePhrase(_ source: String, with replacement: String, in text: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![\(wordCharacters)])\(NSRegularExpression.escapedPattern(for: source))(?![\(wordCharacters)])"
        ) else { return text }
        let mutable = NSMutableString(string: text)
        let range = NSRange(location: 0, length: mutable.length)
        let matches = expression.matches(in: mutable as String, range: range)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        return mutable as String
    }
}
