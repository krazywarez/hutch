import Foundation
import Testing
@testable import Hutch

struct ManPageCatalogTests {
    @Test
    func loadsBundledCatalog() {
        let entries = ManPageCatalog.load()
        #expect(!entries.isEmpty)
        #expect(entries.contains { $0.title == "git.sr.ht" })
        #expect(entries.allSatisfy { $0.url.scheme == "https" })
    }

    @Test
    func fallsBackWhenResourceMissing() {
        // Foundation's own bundle has no man-pages.json, so this exercises the
        // fallback path rather than the bundled resource.
        let entries = ManPageCatalog.load(bundle: Bundle(for: JSONDecoder.self))
        #expect(entries == ManPageCatalog.fallback)
    }

    @Test
    func decodesCatalogJSON() throws {
        let json = """
        [
          { "title": "git.sr.ht", "url": "https://man.sr.ht/git.sr.ht/" },
          { "title": "srht.site", "url": "https://srht.site/" }
        ]
        """
        let entries = try JSONDecoder().decode([ManPageCatalogEntry].self, from: Data(json.utf8))
        #expect(entries.count == 2)
        #expect(entries.first?.title == "git.sr.ht")
        #expect(entries.first?.url == URL(string: "https://man.sr.ht/git.sr.ht/"))
    }
}
