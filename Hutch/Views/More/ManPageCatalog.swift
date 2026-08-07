import Foundation

struct ManPageCatalogEntry: Decodable, Hashable, Identifiable {
    let title: String
    let url: URL

    var id: String { title }
}

enum ManPageCatalog {
    /// Official sr.ht man pages, loaded from the bundled `man-pages.json` that
    /// the scheduled sync workflow keeps in step with man.sr.ht. Falls back to a
    /// built-in list if the resource is missing or unreadable, so the browser is
    /// never empty.
    static func load(bundle: Bundle = .main) -> [ManPageCatalogEntry] {
        guard let url = bundle.url(forResource: "man-pages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ManPageCatalogEntry].self, from: data),
              !entries.isEmpty else {
            return fallback
        }
        return entries
    }

    static let fallback: [ManPageCatalogEntry] = [
        entry("builds.sr.ht", "https://man.sr.ht/builds.sr.ht/"),
        entry("chat.sr.ht", "https://man.sr.ht/chat.sr.ht/"),
        entry("git.sr.ht", "https://man.sr.ht/git.sr.ht/"),
        entry("hg.sr.ht", "https://man.sr.ht/hg.sr.ht/"),
        entry("hub.sr.ht", "https://man.sr.ht/hub.sr.ht/"),
        entry("lists.sr.ht", "https://man.sr.ht/lists.sr.ht/"),
        entry("man.sr.ht", "https://man.sr.ht/man.sr.ht/"),
        entry("meta.sr.ht", "https://man.sr.ht/meta.sr.ht/"),
        entry("paste.sr.ht", "https://man.sr.ht/paste.sr.ht/"),
        entry("sr.ht", "https://man.sr.ht/sr.ht/"),
        entry("srht.site", "https://srht.site/"),
        entry("todo.sr.ht", "https://man.sr.ht/todo.sr.ht/")
    ]

    private static func entry(_ title: String, _ urlString: String) -> ManPageCatalogEntry {
        ManPageCatalogEntry(title: title, url: URL(string: urlString)!)
    }
}
