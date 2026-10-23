import SwiftUI

struct CommitLogView: View {
    let viewModel: RepositoryDetailViewModel

    var body: some View {
        List {
            ForEach(viewModel.commits) { commit in
                NavigationLink(value: commit) {
                    CommitRowView(commit: commit, repository: viewModel.repository)
                }
                .task {
                    await viewModel.loadMoreCommitsIfNeeded(currentItem: commit)
                }
            }
            .themedRow()

            if viewModel.isLoadingMoreCommits {
                LoadingMoreRow()
                .themedRow()
            }
        }
        .themedList()
        .listStyle(.plain)
        .overlay {
            SRHTLoadStateView(
                isLoading: viewModel.isLoadingCommits,
                error: viewModel.error,
                isEmpty: viewModel.commits.isEmpty,
                loadingMessage: "Loading commits…",
                errorTitle: "Couldn't Load Commits",
                retryAction: { await viewModel.loadCommits() }
            ) {
                if viewModel.commits.isEmpty {
                    ContentUnavailableView(
                        "No Commits",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("This repository has no commit history.")
                    )
                }
            }
        }
        .task {
            if viewModel.commits.isEmpty {
                await viewModel.loadCommits()
            }
        }
        .refreshable {
            await viewModel.loadCommits()
        }
        .navigationDestination(for: CommitSummary.self) { commit in
            CommitDetailView(
                commitSummary: commit,
                repository: viewModel.repository
            )
        }
    }
}
