import Foundation
import Testing
import UIKit
@testable import Hutch

@MainActor
struct SyntaxHighlighterTests {
    @Test
    func mapsFileNamesToLanguages() {
        #expect(SyntaxHighlighter.language(forFileName: "Sources/App/Main.swift") == "swift")
        #expect(SyntaxHighlighter.language(forFileName: "server.py") == "python")
        #expect(SyntaxHighlighter.language(forFileName: "index.tsx") == "typescript")
        #expect(SyntaxHighlighter.language(forFileName: "Dockerfile") == "dockerfile")
        #expect(SyntaxHighlighter.language(forFileName: "Makefile") == "makefile")
    }

    @Test
    func returnsNilForUnknownExtensions() {
        #expect(SyntaxHighlighter.language(forFileName: "notes.unknownext") == nil)
        #expect(SyntaxHighlighter.language(forFileName: "LICENSE") == nil)
    }

    @Test
    func highlightsKnownLanguageAsColoredSpans() {
        let highlighter = SyntaxHighlighter(theme: .light)
        let html = highlighter.highlightedHTML(for: "let answer = 42", language: "swift")

        #expect(html?.contains("<span style=\"color:") == true)
        #expect(html?.contains("answer") == true)
    }

    @Test
    func fallsBackToNilForUnsupportedLanguage() {
        let highlighter = SyntaxHighlighter(theme: .dark)
        #expect(highlighter.highlightedHTML(for: "plain text", language: nil) == nil)
        #expect(highlighter.highlightedHTML(for: "plain text", language: "totally-not-a-language") == nil)
    }

    @Test
    func producesAttributedTextForNativeViewer() {
        let highlighter = SyntaxHighlighter(theme: .light)
        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributed = highlighter.attributedText(for: "print(\"hi\")", language: "python", font: font)

        #expect(attributed?.string.contains("print") == true)
    }
}
