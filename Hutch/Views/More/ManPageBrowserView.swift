import SwiftUI

/// Entry point for the man.sr.ht browser in the More tab.
/// Shows the official sr.ht man pages from the bundled catalog, which the
/// scheduled sync workflow keeps current with man.sr.ht.
struct ManPageBrowserView: View {
    private let officialDocs = ManPageCatalog.load()

    var body: some View {
        List {
            Section("Official Man Pages") {
                ForEach(officialDocs) { doc in
                    NavigationLink(value: MoreRoute.manPage(doc.url)) {
                        Text(doc.title)
                    }
                }
                .themedRow()
            }
        }
        .themedList()
        .navigationTitle("Man Pages")
        .navigationBarTitleDisplayMode(.inline)
    }
}
