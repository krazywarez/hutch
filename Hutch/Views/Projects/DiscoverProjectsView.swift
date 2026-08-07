import SwiftUI

@Observable
@MainActor
final class DiscoverProjectsViewModel {
    private(set) var projects: [DiscoveredProject] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var cursor: String?
    private var canLoadMore = true
    private let service: ProjectService

    init(service: ProjectService) {
        self.service = service
    }

    func loadInitial() async {
        guard projects.isEmpty, !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let page = try await service.fetchPublicProjects(cursor: nil)
            projects = page.projects
            cursor = page.cursor
            canLoadMore = page.cursor != nil
        } catch {
            self.error = error.userFacingMessage
        }
    }

    func reload() async {
        cursor = nil
        canLoadMore = true
        projects = []
        await loadInitial()
    }

    func loadMoreIfNeeded(current item: DiscoveredProject) async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        guard let index = projects.firstIndex(of: item), index >= projects.count - 3 else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.fetchPublicProjects(cursor: cursor)
            let existing = Set(projects.map(\.id))
            projects.append(contentsOf: page.projects.filter { !existing.contains($0.id) })
            cursor = page.cursor
            canLoadMore = page.cursor != nil
        } catch {
            self.error = error.userFacingMessage
        }
    }
}

struct DiscoverProjectsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DiscoverProjectsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                SRHTLoadingStateView(message: "Loading projects…")
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = DiscoverProjectsViewModel(service: ProjectService(client: appState.client))
                viewModel = vm
                await vm.loadInitial()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: DiscoverProjectsViewModel) -> some View {
        List {
            ForEach(viewModel.projects) { discovered in
                NavigationLink {
                    ProjectDetailView(
                        project: discovered.project,
                        canManage: discovered.ownerCanonicalName == appState.currentUser?.canonicalName
                    )
                } label: {
                    DiscoveredProjectRow(discovered: discovered)
                }
                .buttonStyle(.plain)
                .task {
                    await viewModel.loadMoreIfNeeded(current: discovered)
                }
            }
            .themedRow()

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .themedRow()
            }
        }
        .themedList()
        .listStyle(.plain)
        .overlay {
            if viewModel.isLoading, viewModel.projects.isEmpty {
                SRHTLoadingStateView(message: "Loading projects…")
            } else if let error = viewModel.error, viewModel.projects.isEmpty {
                SRHTErrorStateView(
                    title: "Couldn't Load Projects",
                    message: error,
                    retryAction: { await viewModel.reload() }
                )
            } else if viewModel.projects.isEmpty {
                ContentUnavailableView(
                    "No Public Projects",
                    systemImage: "sparkle.magnifyingglass",
                    description: Text("Public projects on SourceHut will appear here.")
                )
            }
        }
        .srhtErrorBanner(
            error: Binding(
                get: { viewModel.error },
                set: { viewModel.error = $0 }
            )
        )
        .refreshable {
            await viewModel.reload()
        }
    }
}

private struct DiscoveredProjectRow: View {
    let discovered: DiscoveredProject

    private var project: Project { discovered.project }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.displayName)
                .font(.headline)
                .lineLimit(1)
            Text(discovered.ownerCanonicalName)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let description = project.displayDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
