import Foundation
import Highlightr
import SwiftUI
import UIKit

enum SyntaxHighlightTheme {
    case light
    case dark

    init(userInterfaceStyle: UIUserInterfaceStyle) {
        self = userInterfaceStyle == .dark ? .dark : .light
    }

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }

    /// highlight.js theme names bundled with Highlightr. Xcode-like in light,
    /// a muted dark palette in dark, so highlighting reads as native on both.
    var highlightrName: String {
        switch self {
        case .light: "xcode"
        case .dark: "atom-one-dark"
        }
    }
}

/// Multi-language syntax highlighting backed by Highlightr (highlight.js).
///
/// Highlightr wraps a JavaScriptCore context and is not thread-safe, so each
/// instance must stay on the thread/task that created it. Callers that fail to
/// resolve a language — or hit an unavailable engine — get `nil` and should
/// fall back to plain, escaped text.
final class SyntaxHighlighter {
    private let highlightr: Highlightr?
    private let supportedLanguages: Set<String>

    init(theme: SyntaxHighlightTheme) {
        let engine = Highlightr()
        engine?.setTheme(to: theme.highlightrName)
        highlightr = engine
        supportedLanguages = Set(engine?.supportedLanguages() ?? [])
    }

    /// Full-document highlighted string, or `nil` when the language is unknown
    /// or the engine is unavailable.
    func attributedText(for code: String, language: String?, font: UIFont) -> NSAttributedString? {
        guard let highlightr, let language = resolvedLanguage(language) else { return nil }
        highlightr.theme.setCodeFont(font)
        return highlightr.highlight(code, as: language, fastRender: true)
    }

    /// Inner HTML for a `<code>` element — color-styled `<span>`s — or `nil` to
    /// fall back. Colors are inlined, so the caller must regenerate when the
    /// theme changes.
    func highlightedHTML(for code: String, language: String?) -> String? {
        guard let attributed = attributedText(for: code, language: language, font: Self.htmlMeasurementFont) else {
            return nil
        }
        return Self.html(from: attributed)
    }

    private static let htmlMeasurementFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    private func resolvedLanguage(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !trimmed.isEmpty else {
            return nil
        }
        let mapped = Self.languageAliases[trimmed] ?? trimmed
        return supportedLanguages.contains(mapped) ? mapped : nil
    }

    /// Resolves a filename to a highlight.js language identifier, or `nil` when
    /// there is no confident match (so we render plain rather than mis-highlight).
    static func language(forFileName fileName: String) -> String? {
        let base = (fileName as NSString).lastPathComponent.lowercased()
        if let byName = fileNameLanguages[base] {
            return byName
        }
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return extensionLanguages[ext]
    }

    private static func html(from attributed: NSAttributedString) -> String {
        var html = ""
        let range = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.foregroundColor, in: range, options: []) { value, subrange, _ in
            let fragment = (attributed.string as NSString).substring(with: subrange)
            let escaped = escapeHTML(fragment)
            if let color = value as? UIColor, let hex = color.hexRGBString {
                html += "<span style=\"color:\(hex)\">\(escaped)</span>"
            } else {
                html += escaped
            }
        }
        return html
    }

    /// Fence tags / short names that differ from highlight.js identifiers.
    private static let languageAliases: [String: String] = [
        "js": "javascript",
        "jsx": "javascript",
        "ts": "typescript",
        "tsx": "typescript",
        "py": "python",
        "rb": "ruby",
        "sh": "bash",
        "shell": "bash",
        "zsh": "bash",
        "yml": "yaml",
        "c++": "cpp",
        "cc": "cpp",
        "h": "cpp",
        "hpp": "cpp",
        "cs": "csharp",
        "objc": "objectivec",
        "objective-c": "objectivec",
        "obj-c": "objectivec",
        "html": "xml",
        "htm": "xml",
        "kt": "kotlin",
        "rs": "rust",
        "golang": "go",
        "md": "markdown",
        "ps1": "powershell",
        "yaml": "yaml"
    ]

    /// Filenames without a useful extension.
    private static let fileNameLanguages: [String: String] = [
        "dockerfile": "dockerfile",
        "makefile": "makefile",
        "gnumakefile": "makefile",
        "cmakelists.txt": "cmake",
        "gemfile": "ruby",
        "rakefile": "ruby",
        "podfile": "ruby",
        "package.swift": "swift"
    ]

    private static let extensionLanguages: [String: String] = [
        "swift": "swift",
        "js": "javascript",
        "mjs": "javascript",
        "cjs": "javascript",
        "jsx": "javascript",
        "ts": "typescript",
        "tsx": "typescript",
        "py": "python",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "c": "c",
        "h": "c",
        "cpp": "cpp",
        "cxx": "cpp",
        "cc": "cpp",
        "hpp": "cpp",
        "hxx": "cpp",
        "m": "objectivec",
        "mm": "objectivec",
        "cs": "csharp",
        "java": "java",
        "kt": "kotlin",
        "kts": "kotlin",
        "scala": "scala",
        "php": "php",
        "pl": "perl",
        "pm": "perl",
        "lua": "lua",
        "r": "r",
        "dart": "dart",
        "groovy": "groovy",
        "hs": "haskell",
        "ex": "elixir",
        "exs": "elixir",
        "erl": "erlang",
        "clj": "clojure",
        "sh": "bash",
        "bash": "bash",
        "zsh": "bash",
        "fish": "bash",
        "ps1": "powershell",
        "json": "json",
        "yaml": "yaml",
        "yml": "yaml",
        "toml": "ini",
        "ini": "ini",
        "cfg": "ini",
        "conf": "ini",
        "xml": "xml",
        "html": "xml",
        "htm": "xml",
        "css": "css",
        "scss": "scss",
        "sass": "scss",
        "less": "less",
        "sql": "sql",
        "md": "markdown",
        "markdown": "markdown",
        "diff": "diff",
        "patch": "diff",
        "cmake": "cmake",
        "gradle": "groovy",
        "vim": "vim"
    ]
}

private extension UIColor {
    /// `#rrggbb` for HTML inline styles, or `nil` if the color isn't RGB-convertible.
    var hexRGBString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let clamp: (CGFloat) -> Int = { Int((max(0, min(1, $0)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", clamp(red), clamp(green), clamp(blue))
    }
}
