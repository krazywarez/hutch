import Foundation
import OrgSwift
import Testing
@testable import Hutch

@MainActor
struct ReadmeViewTests {

    @Test
    func sanitizedReadmeLinkURLStringRejectsUnexpectedSchemes() {
        #expect(sanitizedReadmeLinkURLString("javascript:alert(1)") == nil)
        #expect(sanitizedReadmeLinkURLString("file:///tmp/readme") == nil)
        #expect(sanitizedReadmeLinkURLString("data:text/html;base64,SGVsbG8=") == nil)
    }

    @Test
    func processInlineDropsUnsafeMarkdownLinks() {
        let rendered = processInline("[click me](javascript:alert)")

        #expect(rendered == "click me")
        #expect(!rendered.contains("href="))
        #expect(!rendered.contains("javascript:"))
    }

    @Test
    func sanitizedReadmeLinkURLStringAllowsExpectedDestinations() {
        #expect(sanitizedReadmeLinkURLString("https://example.com/docs?q=1") == "https://example.com/docs?q=1")
        #expect(sanitizedReadmeLinkURLString("mailto:test@example.com") == "mailto:test@example.com")
        #expect(sanitizedReadmeLinkURLString("#readme") == "#readme")
    }
}

@MainActor
struct MarkdownRenderingTests {

    @Test
    func markdownOrderedList() {
        let html = markdownToHTML("1. First\n2. Second")

        #expect(html.contains("<ol>"))
        #expect(html.contains("<li>"))
    }

    @Test
    func markdownBlockquote() {
        let html = markdownToHTML("> This is a quote")

        #expect(html.contains("<blockquote>"))
    }

    @Test
    func markdownTable() {
        let input = "| A | B |\n|---|---|\n| 1 | 2 |"
        let html = markdownToHTML(input)

        #expect(html.contains("<table>"))
        #expect(html.contains("<th>"))
    }

    @Test
    func markdownTableAlignment() {
        let input = "| Left | Center | Right |\n|:-----|:------:|------:|\n| a | b | c |"
        let html = markdownToHTML(input)

        #expect(html.contains("text-align: left;"))
        #expect(html.contains("text-align: center;"))
        #expect(html.contains("text-align: right;"))
    }

    @Test
    func markdownStrikethrough() {
        let html = markdownToHTML("~~deleted~~")

        #expect(html.contains("<del>"))
    }

    @Test
    func markdownDeepHeadings() {
        let html = markdownToHTML("#### Level 4")

        #expect(html.contains("<h4>"))
    }

    @Test
    func markdownHardWrapNormalization() {
        let html = markdownToHTML("line one\nline two")

        #expect(!html.contains("line one\nline two"))
        #expect(html.contains("line one"))
        #expect(html.contains("line two"))
    }

    @Test
    func markdownSoftBreakIsSpace() {
        let html = markdownToHTML("word one\nword two")

        #expect(html.contains("word one word two") || (html.contains("word one") && html.contains("word two")))
        #expect(!html.contains("<br>"))
    }

    @Test
    func markdownUnsafeLinkDropped() {
        let html = markdownToHTML("[click](javascript:alert(1))")

        #expect(!html.contains("href="))
        #expect(!html.contains("javascript:"))
    }

    @Test
    func markdownRelativeLinkWithoutResolverDropped() {
        let html = markdownToHTML("[LICENSE](LICENSE)")

        #expect(!html.contains("href="))
        #expect(html.contains("LICENSE"))
    }

    @Test
    func markdownRelativeLinkWithResolverRendersAnchor() {
        let html = markdownToHTML(
            "[LICENSE](LICENSE)",
            linkURLResolver: { source in
                source == "LICENSE" ? "https://git.sr.ht/~ccleberg/Hutch/blob/HEAD/LICENSE" : nil
            }
        )

        #expect(html.contains(#"href="https://git.sr.ht/~ccleberg/Hutch/blob/HEAD/LICENSE""#))
        #expect(html.contains(">LICENSE</a>"))
    }

    @Test
    func markdownFragmentLinkWithResolverPreservesFragment() {
        let html = markdownToHTML(
            "[section](#install)",
            linkURLResolver: { hutchOptions.resolvedLinkURL($0) }
        )

        #expect(html.contains("href=\"#install\""))
    }

    @Test
    func markdownImageRenders() {
        let html = markdownToHTML("![logo](https://example.com/logo.png)")

        #expect(html.contains("<img src=\"https://example.com/logo.png\" alt=\"logo\">"))
        #expect(!html.contains(#"\"#))
    }

    @Test
    func markdownLinkedImageRendersAnchor() {
        let html = markdownToHTML("[![badge](https://example.com/badge.png)](https://example.com/build)")

        #expect(html.contains("<a href=\"https://example.com/build\">"))
        #expect(html.contains("<img src=\"https://example.com/badge.png\" alt=\"badge\">"))
        #expect(!html.contains(#"\"#))
    }

    @Test
    func markdownInlineCodeEscaping() {
        let html = processInline("`<b>`")

        #expect(html.contains("<code>"))
        #expect(html.contains("&lt;b&gt;"))
        #expect(!html.contains("<b>"))
    }

    @Test
    func markdownPlainEmailAutolinks() {
        let html = processInline("Contact root@krz.sh")

        #expect(html.contains(#"href="mailto:root@krz.sh""#))
        #expect(html.contains(">root@krz.sh</a>"))
    }

    @Test
    func markdownImageQueryStringPreservesAmpersands() {
        let html = processInline("![badge](https://sonarcloud.io/api/project_badges/measure?project=ccleberg_Hutch&metric=security_rating)")

        // `&amp;` is the correct encoding for `&` in an attribute value, so the
        // failure mode to guard against is double-escaping, which would make the
        // browser request a literal "&amp;" in the query string.
        #expect(html.contains("metric=security_rating"))
        #expect(!html.contains("&amp;amp;"))
        #expect(html.contains("<img"))
    }

    @Test
    func markdownLinkedImagesWithQueryStringsRenderAllImages() {
        let html = markdownToHTML("""
        [![builds.sr.ht status](https://builds.sr.ht/~ccleberg/Hutch.svg)](https://builds.sr.ht/~ccleberg/Hutch?)
        [![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=ccleberg_Hutch&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=ccleberg_Hutch)
        [![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=ccleberg_Hutch&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=ccleberg_Hutch)
        """)

        #expect(html.contains("Hutch.svg"))
        #expect(html.contains("metric=security_rating"))
        #expect(html.contains("metric=reliability_rating"))
        #expect(!html.contains("amp;amp;"))
    }

    @Test
    func markdownAllowsSafeInlineHTML() {
        let html = processInline(#"<strong>Bold</strong> <a href="https://example.com">Link</a>"#)

        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains(#"<a href="https://example.com">Link</a>"#))
    }

    @Test
    func markdownProtectedTokensDoNotLeak() {
        let html = processInline(#"<a href="https://example.com">Back to top</a> `yoshi [ARG] <FILE>`"#)

        #expect(!html.contains("ZZPROTECTED"))
        #expect(html.contains(#"<a href="https://example.com">Back to top</a>"#))
        #expect(html.contains("<code>yoshi [ARG] &lt;FILE&gt;</code>"))
    }
}

/// The repository context a README on git.sr.ht resolves against.
private let hutchOptions = OrgRenderOptions(
    host: "git.sr.ht",
    owner: "~ccleberg",
    repositoryName: "Hutch",
    ref: "HEAD",
    readmePath: "README.md"
)

/// Resolution lives in OrgSwift and is shared by both README formats, so a relative target
/// in a Markdown README lands where the same target in an Org one does.
@MainActor
struct RepositoryAssetURLTests {

    @Test
    func repositoryAssetURLPercentEncodesImagePaths() {
        #expect(hutchOptions.resolvedImageURL("images/My Logo.png")
            == "https://git.sr.ht/~ccleberg/Hutch/blob/HEAD/images/My%20Logo.png")
    }
}

@MainActor
struct RepositoryLinkURLTests {

    @Test
    func repositoryLinkURLResolvesRelativePath() {
        #expect(hutchOptions.resolvedLinkURL("LICENSE")
            == "https://git.sr.ht/~ccleberg/Hutch/blob/HEAD/LICENSE")
    }

    @Test
    func repositoryLinkURLResolvesSubdirectoryRelativePath() {
        #expect(hutchOptions.resolvedLinkURL("docs/SECURITY.md")
            == "https://git.sr.ht/~ccleberg/Hutch/blob/HEAD/docs/SECURITY.md")
    }

    @Test
    func repositoryLinkURLPassesThroughAbsoluteURL() {
        #expect(hutchOptions.resolvedLinkURL("https://example.com/page")
            == "https://example.com/page")
    }

    @Test
    func repositoryLinkURLPassesThroughFragment() {
        #expect(hutchOptions.resolvedLinkURL("#install") == "#install")
    }

    @Test
    func repositoryLinkURLPassesThroughMailto() {
        #expect(hutchOptions.resolvedLinkURL("mailto:hello@example.com")
            == "mailto:hello@example.com")
    }

    /// The host is carried by the options rather than patched into a finished URL, so a
    /// self-hosted instance resolves without string-replacing "git.sr.ht" out of the result.
    @Test
    func repositoryLinkURLUsesTheConfiguredHost() {
        var options = hutchOptions
        options.host = "git.example.org"
        #expect(options.resolvedLinkURL("LICENSE")
            == "https://git.example.org/~ccleberg/Hutch/blob/HEAD/LICENSE")
    }
}
