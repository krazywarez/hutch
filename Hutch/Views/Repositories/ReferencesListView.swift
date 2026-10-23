import SwiftUI

struct ReferencesListView: View {
    let viewModel: RepositoryDetailViewModel

    var body: some View {
        List {
            if let defaultBranch = viewModel.defaultBranchReference {
                referenceSection(
                    defaultBranch,
                    header: "Default Branch",
                    seeAll: "See All Branches",
                    title: "Branches",
                    references: viewModel.branches,
                    prefix: "refs/heads/"
                )
            }

            if let latestTag = viewModel.latestTagReference {
                referenceSection(
                    latestTag,
                    header: "Latest Tag",
                    seeAll: "See All Tags",
                    title: "Tags",
                    references: viewModel.tags,
                    prefix: "refs/tags/"
                )
            }
        }
        .themedList()
        .listStyle(.insetGrouped)
        .overlay {
            SRHTLoadStateView(
                isLoading: viewModel.isLoadingRefs,
                error: viewModel.error,
                isEmpty: viewModel.branches.isEmpty && viewModel.tags.isEmpty,
                loadingMessage: "Loading references…",
                errorTitle: "Couldn't Load References",
                retryAction: { await viewModel.loadReferences() }
            ) {
                if viewModel.branches.isEmpty, viewModel.tags.isEmpty {
                    ContentUnavailableView(
                        "No References",
                        systemImage: "arrow.triangle.branch",
                        description: Text("This repository has no branches or tags.")
                    )
                }
            }
        }
        .task {
            if viewModel.branches.isEmpty, viewModel.tags.isEmpty {
                await viewModel.loadReferences()
            }
        }
        .refreshable {
            await viewModel.loadReferences()
        }
    }

    @ViewBuilder
    /// One reference with a link to all of its kind.
    private func referenceSection(
        _ reference: ReferenceDetail,
        header: String,
        seeAll: LocalizedStringKey,
        title: String,
        references: [ReferenceDetail],
        prefix: String
    ) -> some View {
        Section {
            ReferenceRow(reference: reference, prefix: prefix)
                .themedRow()

            NavigationLink(seeAll) {
                ReferencesDetailListView(title: title, references: references, prefix: prefix)
            }
            .themedRow()
        } header: {
            sectionHeader(title: header)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
        }
    }
}

private struct ReferencesDetailListView: View {
    let title: String
    let references: [ReferenceDetail]
    let prefix: String

    var body: some View {
        List {
            ForEach(references, id: \.name) { reference in
                ReferenceRow(reference: reference, prefix: prefix)
                    .themedRow()
            }
        }
        .themedList()
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .overlay {
            if references.isEmpty {
                ContentUnavailableView(
                    "No \(title)",
                    systemImage: prefix.contains("tags") ? "tag" : "arrow.triangle.branch",
                    description: Text("This repository does not have any \(title.lowercased()).")
                )
            }
        }
    }
}

private struct ReferenceRow: View {
    let reference: ReferenceDetail
    let prefix: String

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName)
                        .font(.body.monospaced())
                    if let date = reference.date {
                        Text(date.relativeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            Spacer()

            Text(String((reference.target ?? "").prefix(8)))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var shortName: String {
        if reference.name.hasPrefix(prefix) {
            String(reference.name.dropFirst(prefix.count))
        } else {
            reference.name
        }
    }

    private var icon: String {
        prefix.contains("tags") ? "tag" : "arrow.triangle.branch"
    }

    private var iconColor: Color {
        prefix.contains("tags") ? .orange : .blue
    }
}
