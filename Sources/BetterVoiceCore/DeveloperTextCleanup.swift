import Foundation

public enum DeveloperAppProfile: String, Sendable {
    case general
    case terminal
    case editor
    case ai

    public static func infer(bundleIdentifier: String?, applicationName: String?) -> Self {
        let value = "\(bundleIdentifier ?? "") \(applicationName ?? "")".lowercased()
        if value.contains("terminal") || value.contains("iterm") || value.contains("ghostty") ||
            value.contains("warp") || value.contains("kitty") || value.contains("wezterm") {
            return .terminal
        }
        if value.contains("xcode") || value.contains("visual studio code") || value.contains("cursor") ||
            value.contains("windsurf") || value.contains("neovim") || value.contains("code.editor") {
            return .editor
        }
        if value.contains("chatgpt") || value.contains("claude") || value.contains("codex") {
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

    public static func apply(_ text: String, profile: DeveloperAppProfile = .general) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        if profile == .terminal || profile == .editor || profile == .ai {
            for (source, replacement) in spokenAcronyms {
                result = replaceWholePhrase(source, with: replacement, in: result)
            }
        }
        for (source, replacement) in terms {
            result = replaceWholePhrase(source, with: replacement, in: result)
        }
        return result
    }

    private static func replaceWholePhrase(_ source: String, with replacement: String, in text: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![A-Za-z0-9_])\(NSRegularExpression.escapedPattern(for: source))(?![A-Za-z0-9_])"
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
