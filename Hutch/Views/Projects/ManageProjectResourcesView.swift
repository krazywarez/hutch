import SwiftUI

@Observable
@MainActor
final class ManageProjectResourcesViewModel {
    private(set) var sources: [Project.SourceRepo]
    private(set) var trackers: [Project.Tracker]
    private(set) var mailingLists: [Project.MailingList]
    private(set) var busyID: String?
    var error: String?

    let projectID: String
    let projectName: String
    private let service: ProjectService
    private let onChange: () async -> Void

    init(project: Project, service: ProjectService, onChange: @escaping () async -> Void) {
        projectID = project.id
        projectName = project.displayName
        sources = project.sources
        trackers = project.trackers
        mailingLists = project.mailingLists
        self.service = service
        self.onChange = onChange
    }

    /// rids already linked, so the candidate pickers can hide them.
    var linkedRIDs: Set<String> {
        Set(sources.map(\.id) + trackers.map(\.id) + mailingLists.map(\.id))
    }

    func unlink(source: Project.SourceRepo) async {
        await mutate(id: source.id) {
            try await self.service.unlinkSource(projectID: self.projectID, sourceRepoID: source.id)
            self.sources.removeAll { $0.id == source.id }
        }
    }

    func unlink(tracker: Project.Tracker) async {
        await mutate(id: tracker.id) {
            try await self.service.unlinkTracker(projectID: self.projectID, trackerID: tracker.id)
            self.trackers.removeAll { $0.id == tracker.id }
        }
    }

    func unlink(mailingList: Project.MailingList) async {
        await mutate(id: mailingList.id) {
            try await self.service.unlinkMailingList(projectID: self.projectID, listID: mailingList.id)
            self.mailingLists.removeAll { $0.id == mailingList.id }
        }
    }

    func link(_ resource: LinkableResource) async {
        await mutate(id: resource.rid) {
            switch resource.kind {
            case .source:
                try await self.service.linkSource(projectID: self.projectID, sourceRepoID: resource.rid)
            case .tracker:
                try await self.service.linkTracker(projectID: self.projectID, trackerID: resource.rid)
            case .mailingList:
                try await self.service.linkMailingList(projectID: self.projectID, listID: resource.rid)
            }
            try await self.reload()
        }
    }

    func candidates(for kind: LinkableResource.Kind) async throws -> [LinkableResource] {
        let all: [LinkableResource]
        switch kind {
        case .source: all = try await service.fetchLinkableSources()
        case .tracker: all = try await service.fetchLinkableTrackers()
        case .mailingList: all = try await service.fetchLinkableMailingLists()
        }
        let linked = linkedRIDs
        return all.filter { !linked.contains($0.rid) }
    }

    private func reload() async throws {
        let project = try await service.fetchProjectDetail(rid: projectID)
        sources = project.sources
        trackers = project.trackers
        mailingLists = project.mailingLists
    }

    private func mutate(id: String, _ work: @escaping () async throws -> Void) async {
        guard busyID == nil else { return }
        busyID = id
        error = nil
        defer { busyID = nil }
        do {
            try await work()
            await onChange()
        } catch {
            self.error = error.userFacingMessage
        }
    }
}

struct ManageProjectResourcesView: View {
    let project: Project
    let onChange: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ManageProjectResourcesViewModel?
    @State private var addKind: LinkableResource.Kind?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    SRHTLoadingStateView(message: "Loading…")
                }
            }
            .navigationTitle("Linked Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Add Repository") { addKind = .source }
                        Button("Add Tracker") { addKind = .tracker }
                        Button("Add Mailing List") { addKind = .mailingList }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add linked resource")
                }
            }
            .sheet(item: Binding(get: { addKind.map { AddKind(kind: $0) } }, set: { addKind = $0?.kind })) { wrapper in
                if let viewModel {
                    LinkableResourcePicker(kind: wrapper.kind, viewModel: viewModel)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ManageProjectResourcesViewModel(
                    project: project,
                    service: ProjectService(client: appState.client),
                    onChange: onChange
                )
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ManageProjectResourcesViewModel) -> some View {
        List {
            resourceSection(
                title: "Repositories",
                items: viewModel.sources,
                busyID: viewModel.busyID,
                label: { "\($0.ownerUsername)/\($0.displayName)" },
                onDelete: { await viewModel.unlink(source: $0) }
            )
            resourceSection(
                title: "Trackers",
                items: viewModel.trackers,
                busyID: viewModel.busyID,
                label: { "\($0.ownerUsername)/\($0.displayName)" },
                onDelete: { await viewModel.unlink(tracker: $0) }
            )
            resourceSection(
                title: "Mailing Lists",
                items: viewModel.mailingLists,
                busyID: viewModel.busyID,
                label: { "\($0.ownerUsername)/\($0.displayName)" },
                onDelete: { await viewModel.unlink(mailingList: $0) }
            )

            if viewModel.sources.isEmpty, viewModel.trackers.isEmpty, viewModel.mailingLists.isEmpty {
                Section {
                    Text("No linked resources. Use + to add repositories, trackers, or mailing lists.")
                        .foregroundStyle(.secondary)
                        .themedRow()
                }
            }
        }
        .themedList()
        .srhtErrorBanner(
            error: Binding(get: { viewModel.error }, set: { viewModel.error = $0 })
        )
    }

    @ViewBuilder
    private func resourceSection<Item: Identifiable>(
        title: String,
        items: [Item],
        busyID: String?,
        label: @escaping (Item) -> String,
        onDelete: @escaping (Item) async -> Void
    ) -> some View where Item.ID == String {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    HStack {
                        Text(label(item))
                            .font(.body.monospaced())
                            .lineLimit(1)
                        Spacer()
                        if busyID == item.id {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .themedRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await onDelete(item) }
                        } label: {
                            Label("Unlink", systemImage: "link.badge.minus")
                        }
                    }
                }
            }
        }
    }
}

private struct AddKind: Identifiable {
    let kind: LinkableResource.Kind
    var id: String {
        switch kind {
        case .source: "source"
        case .tracker: "tracker"
        case .mailingList: "mailingList"
        }
    }
}

private struct LinkableResourcePicker: View {
    let kind: LinkableResource.Kind
    let viewModel: ManageProjectResourcesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [LinkableResource] = []
    @State private var isLoading = true
    @State private var error: String?

    private var title: String {
        switch kind {
        case .source: "Add Repository"
        case .tracker: "Add Tracker"
        case .mailingList: "Add Mailing List"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SRHTLoadingStateView(message: "Loading…")
                } else if let error {
                    SRHTErrorStateView(title: "Couldn't Load", message: error, retryAction: { await load() })
                } else if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Add",
                        systemImage: "checkmark.circle",
                        description: Text("There are no more resources of this type to link.")
                    )
                } else {
                    List(candidates) { candidate in
                        Button {
                            Task {
                                await viewModel.link(candidate)
                                dismiss()
                            }
                        } label: {
                            Text(candidate.displayName)
                                .font(.body.monospaced())
                                .lineLimit(1)
                        }
                        .themedRow()
                    }
                    .themedList()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            candidates = try await viewModel.candidates(for: kind)
        } catch {
            self.error = error.userFacingMessage
        }
        isLoading = false
    }
}
