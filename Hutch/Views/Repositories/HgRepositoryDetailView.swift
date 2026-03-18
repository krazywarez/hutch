import SwiftUI

struct HgRepositoryDetailView: View {
    let repository: RepositorySummary
    let onDeleted: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: HgRepositoryDetailViewModel?
    @State private var selectedTab: HgRepositoryDetailViewModel.Tab = .summary
    @State private var showSettings = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            HgRepositorySettingsView(
                repository: repository,
                client: appState.client,
                onDeleted: {
                    dismiss()
                    onDeleted?()
                }
            )
        }
        .task {
            if viewModel == nil {
                let vm = HgRepositoryDetailViewModel(repository: repository, client: appState.client)
                viewModel = vm
                async let summary: () = vm.loadSummary()
                async let browse: () = vm.loadBrowseRoot()
                async let log: () = vm.loadLog()
                _ = await (summary, browse, log)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(HgRepositoryDetailViewModel.Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case .summary:
                summaryTab(viewModel)
            case .browse:
                browseTab(viewModel)
            case .log:
                logTab(viewModel)
            case .tags:
                revisionsList(viewModel.tags, emptyTitle: "No Tags", emptyDescription: "This repository does not have any tags.")
            case .branches:
                revisionsList(viewModel.branches, emptyTitle: "No Branches", emptyDescription: "This repository does not have any named branches.")
            case .bookmarks:
                revisionsList(viewModel.bookmarks, emptyTitle: "No Bookmarks", emptyDescription: "This repository does not have any bookmarks.")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private func summaryTab(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        if viewModel.isLoadingSummary && !viewModel.summaryLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCards(viewModel)

                    if let readmeView = readmeContentView(viewModel) {
                        readmeView
                    } else {
                        ContentUnavailableView(
                            "No README",
                            systemImage: "doc.text",
                            description: Text("This repository does not have a README file.")
                        )
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.loadSummary()
            }
        }
    }

    private func summaryCards(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Visibility", value: visibilityLabel(repository.visibility))
            LabeledContent("Publishing", value: viewModel.nonPublishing ? "Non-publishing" : "Publishing")

            if let description = repository.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(description)
                }
            }

            if let tip = viewModel.tip {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tip")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(tip.title)
                        .font(.headline)
                    HStack {
                        Text(tip.displayShortId)
                            .font(.caption.monospaced())
                        Spacer()
                        Text(tip.author.time.relativeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(tip.author.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func browseTab(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        VStack(spacing: 0) {
            browseBreadcrumbs(viewModel)
            Divider()

            if viewModel.isLoadingBrowse {
                Spacer()
                ProgressView()
                Spacer()
            } else if let selectedFilePath = viewModel.selectedFilePath, let fileContent = viewModel.fileContent {
                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal]) {
                        Text(fileContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                            .padding()
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button("Back to directory") {
                        viewModel.dismissFileView()
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                }
                .navigationTitle(selectedFilePath.split(separator: "/").last.map(String.init) ?? repository.name)
            } else if viewModel.files.isEmpty {
                ContentUnavailableView(
                    "No Files",
                    systemImage: "folder",
                    description: Text("This revision does not contain any browsable files.")
                )
            } else {
                List(viewModel.files) { file in
                    Label {
                        Text(displayFileName(file.name))
                            .font(.body.monospaced())
                    } icon: {
                        Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(file.isDirectory ? .blue : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await viewModel.openFile(file) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable {
            await viewModel.loadBrowseRoot()
        }
    }

    private func browseBreadcrumbs(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.navigateToPath(index: 0) }
                } label: {
                    Text("root")
                        .font(.subheadline.monospaced())
                }
                .buttonStyle(.plain)

                ForEach(Array(viewModel.pathStack.enumerated()), id: \.offset) { index, component in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button {
                        Task { await viewModel.navigateToPath(index: index + 1) }
                    } label: {
                        Text(component)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let selectedFilePath = viewModel.selectedFilePath {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(selectedFilePath.split(separator: "/").last.map(String.init) ?? selectedFilePath)
                        .font(.subheadline.monospaced())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private func logTab(_ viewModel: HgRepositoryDetailViewModel) -> some View {
        List {
            ForEach(viewModel.log) { revision in
                revisionRow(revision)
                    .task {
                        await viewModel.loadMoreLogIfNeeded(currentItem: revision)
                    }
            }

            if viewModel.isLoadingMoreLog {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.isLoadingLog {
                ProgressView()
            } else if viewModel.log.isEmpty {
                ContentUnavailableView(
                    "No Revisions",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("This repository has no revision history.")
                )
            }
        }
        .refreshable {
            await viewModel.loadLog()
        }
    }

    @ViewBuilder
    private func revisionsList(_ revisions: [HgRevision], emptyTitle: String, emptyDescription: String) -> some View {
        if revisions.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "tray",
                description: Text(emptyDescription)
            )
        } else {
            List(revisions) { revision in
                revisionRow(revision)
            }
            .listStyle(.plain)
        }
    }

    private func revisionRow(_ revision: HgRevision) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(revision.primaryName)
                    .font(.headline)
                Spacer()
                Text(revision.displayShortId)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(revision.title)
                .font(.subheadline)

            if let body = revision.body {
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(revision.author.name)
                Spacer()
                Text(revision.author.time.relativeDescription)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func readmeContentView(_ viewModel: HgRepositoryDetailViewModel) -> AnyView? {
        let imageURLResolver = makeImageURLResolver(viewModel)

        guard let content = viewModel.readmeContent else {
            return nil
        }

        switch content {
        case .html(let html):
            return AnyView(
                HTMLWebView(html: html, colorScheme: colorScheme)
                    .frame(minHeight: 400)
            )
        case .markdown(let text):
            return AnyView(
                HTMLWebView(
                    html: markdownToHTML(text, imageURLResolver: imageURLResolver),
                    colorScheme: colorScheme
                )
                .frame(minHeight: 400)
            )
        case .org(let text):
            return AnyView(
                HTMLWebView(
                    html: orgToHTML(text, imageURLResolver: imageURLResolver),
                    colorScheme: colorScheme
                )
                .frame(minHeight: 400)
            )
        case .plainText(let text):
            return AnyView(
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
        }
    }

    private func makeImageURLResolver(_ viewModel: HgRepositoryDetailViewModel) -> (String) -> String? {
        let owner = repository.owner.canonicalName
        let repositoryName = repository.name
        let readmePath = viewModel.readmePath

        return { source in
            resolveRepositoryAssetURL(
                source,
                owner: owner,
                repositoryName: repositoryName,
                readmePath: readmePath
            )?
            .replacingOccurrences(of: "git.sr.ht", with: "hg.sr.ht")
        }
    }

    private func displayFileName(_ name: String) -> String {
        name.hasSuffix("/") ? String(name.dropLast()) : name
    }

    private func visibilityLabel(_ visibility: Visibility) -> String {
        switch visibility {
        case .public:
            return "Public"
        case .unlisted:
            return "Unlisted"
        case .private:
            return "Private"
        }
    }
}
