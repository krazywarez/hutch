import Foundation
import OrgSwiftUI
import Testing
@testable import Hutch

/// `SyntaxHighlighter` as an `OrgCodeStyler` — the native counterpart to the HTML path.
/// The renderer it feeds is covered by org-swift's own tests.
@MainActor
struct OrgNativeRenderingTests {

    @Test
    func syntaxHighlighterStylesCodeNatively() throws {
        let highlighter = SyntaxHighlighter(theme: .dark)
        let styled = try #require(
            highlighter.highlighted(code: "let x = 1\nprint(x)", language: "swift")
        )

        #expect(String(styled.characters) == "let x = 1\nprint(x)")

        // Highlighting means more than one color across the run, in a monospaced font that
        // scales with Dynamic Type — which the fixed-size HTML never did.
        let colors = Set(styled.runs.compactMap { $0.foregroundColor })
        #expect(colors.count > 1)
        #expect(styled.runs.allSatisfy { $0.font != nil })

        // An unknown language falls back to plain rather than mis-highlighting.
        #expect(highlighter.highlighted(code: "+++", language: "notalanguage") == nil)
    }
}
