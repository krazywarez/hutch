import SwiftUI

struct BuildDetailView: View {
    let jobId: Int

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var viewModel: BuildDetailViewModel?
    @State private var rebuiltJobId: Int?
    @State private var selectedTaskName: String?
    @State private var showEditResubmitSheet = false
    @State private var showCancelConfirmation = false
    @State private var isOpeningRepository = false

    private var isPresentingLogSheet: Bool {
        selectedTaskName != nil
    }

    var body: some View {
        Group {
            if let viewModel {
                detailContent(viewModel)
            } else {
                SRHTLoadingStateView(message: "Loading build…")
            }
        }
        .navigationTitle("Job #\(jobId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let browserURL = viewModel?.job.flatMap({ SRHTWebURL.build(jobId: $0.id, ownerCanonicalName: $0.owner.canonicalName) }) {
                    Menu {
                        Button {
                            openURL(browserURL)
                        } label: {
                            Label("Open in Browser", systemImage: "safari")
                        }

                        Button {
                            appState.copyToPasteboard(browserURL.absoluteString, label: "build URL")
                        } label: {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }

                        if let job = viewModel?.job {
                            Button {
                                appState.copyToPasteboard(String(job.id), label: "job ID")
                            } label: {
                                Label("Copy Job ID", systemImage: "number")
                            }

                            if let note = job.note, !note.isEmpty {
                                Button {
                                    appState.copyToPasteboard(note, label: "build note")
                                } label: {
                                    Label("Copy Note", systemImage: "text.alignleft")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Build actions")
                }

                SRHTShareButton(
                    url: viewModel?.job.flatMap { SRHTWebURL.build(jobId: $0.id, ownerCanonicalName: $0.owner.canonicalName) },
                    target: .build
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { rebuiltJobId != nil },
            set: { isPresented in
                if !isPresented {
                    rebuiltJobId = nil
                }
            }
        )) {
            if let rebuiltJobId {
                BuildDetailView(jobId: rebuiltJobId)
            }
        }
        .sheet(isPresented: $showEditResubmitSheet) {
            if let viewModel, let job = viewModel.job {
                EditResubmitBuildSheet(viewModel: viewModel, job: job) { jobId in
                    showEditResubmitSheet = false
                    rebuiltJobId = jobId
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedTaskName != nil },
            set: { isPresented in
                if !isPresented {
                    selectedTaskName = nil
                }
            }
        )) {
            if let selectedTaskName, let viewModel {
                NavigationStack {
                    BuildTaskLogView(taskName: selectedTaskName, viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    self.selectedTaskName = nil
                                }
                            }
                        }
                }
            } else {
                NavigationStack {
                    SRHTLoadingStateView(message: "Loading…")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    self.selectedTaskName = nil
                                }
                            }
                        }
                }
            }
        }
        .alert("Cancel Build?", isPresented: $showCancelConfirmation) {
            Button("Keep Running", role: .cancel) {
                // Alert dismissal is implicit; no additional action required.
            }
            Button("Cancel Build", role: .destructive) {
                Task { await viewModel?.cancelJob() }
            }
        } message: {
            Text("The build will stop as soon as possible.")
        }
        .task {
            if viewModel == nil {
                let vm = BuildDetailViewModel(jobId: jobId, client: appState.client)
                viewModel = vm
                if appState.isDebugModeEnabled {
                    await vm.loadJobWithDebugCapture()
                } else {
                    await vm.loadJob()
                }
                vm.startAutoRefresh()
            }
        }
        .onAppear {
            viewModel?.startAutoRefresh()
        }
        .onDisappear {
            guard !isPresentingLogSheet else { return }
            viewModel?.stopAutoRefresh()
        }
    }

    @ViewBuilder
    private func detailContent(_ viewModel: BuildDetailViewModel) -> some View {
        SRHTLoadStateView(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            isEmpty: viewModel.job == nil,
            loadingMessage: "Loading build…",
            errorTitle: "Couldn't Load Build",
            retryAction: { await reloadDetail(viewModel) }
        ) {
            if let job = viewModel.job {
                List {
                    cacheSection(job, viewModel)

                    detailsSection(job, viewModel)

                    debugSection(job, viewModel)

                    sourceSection(job, viewModel)

                    artifactsSection(job, viewModel)

                    // Per-task logs
                    taskSections(job, viewModel)

                    // Cancel button
                    cancelSection(job, viewModel)

                    rebuildSection(job, viewModel)
                }
                .themedList()
                .task(id: job.id) {
                    RecentActivityStore.recordBuild(
                        jobId: job.id,
                        title: recentActivityTitle(for: job),
                        defaults: appState.accountDefaults
                    )
                }
                .refreshable {
                    await reloadDetail(viewModel)
                }
                .srhtErrorBanner(error: Binding(
                    get: { viewModel.error },
                    set: { viewModel.error = $0 }
                ))
                .srhtErrorBanner(error: Binding(
                    get: { viewModel.actionError },
                    set: { _ in viewModel.dismissActionError() }
                ))
            }
        }
    }

    private func openRepository(ownerCanonicalName: String, repositoryName: String) {
        guard !isOpeningRepository else { return }
        isOpeningRepository = true
        Task {
            defer { isOpeningRepository = false }
            do {
                let ownerUsername = ownerCanonicalName.hasPrefix("~") ? String(ownerCanonicalName.dropFirst()) : ownerCanonicalName
                let repository = try await appState.resolveRepository(owner: ownerUsername, name: repositoryName)
                appState.navigateToRepository(repository)
            } catch {
                appState.presentRepositoryDeepLinkError()
            }
        }
    }

    private func reloadDetail(_ viewModel: BuildDetailViewModel) async {
        if appState.isDebugModeEnabled {
            await viewModel.loadJobWithDebugCapture()
        } else {
            await viewModel.loadJob()
        }
    }

    private func recentActivityTitle(for job: JobDetail) -> String {
        if let note = job.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        if !job.tags.isEmpty {
            return job.tags.joined(separator: ", ")
        }
        return "Job #\(job.id)"
    }


    @ViewBuilder
    private func cancelSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if job.status.isCancellable {
            Section {
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    HStack {
                        Text("Cancel Build")
                        if viewModel.isCancelling {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isCancelling)
                .themedRow()
            }
        }
    }

    @ViewBuilder
    private func taskSections(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if !job.tasks.isEmpty {
            ForEach(job.tasks) { task in
                Section {
                    Button {
                        selectedTaskName = task.name
                    } label: {
                        HStack {
                            Text(task.status.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .themedRow()
                } header: {
                    HStack(spacing: 6) {
                        TaskStatusIcon(status: task.status)
                        Text(task.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artifactsSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if !job.artifacts.isEmpty {
            Section {
                ForEach(job.artifacts) { artifact in
                    BuildArtifactRow(artifact: artifact) {
                        guard let url = artifact.url else { return }
                        openURL(url)
                    }
                }
                .themedRow()
            } header: {
                Text("Artifacts")
            } footer: {
                if job.artifacts.contains(where: { !$0.isDownloadable }) {
                    Text("Artifacts without a download URL are no longer available for download.")
                }
            }
        }
    }

    @ViewBuilder
    private func sourceSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if let repositoryReference = HomeViewModel.primaryRepositoryReference(in: job.manifest) {
            Section("Source") {
                Button {
                    openRepository(ownerCanonicalName: repositoryReference.ownerCanonicalName, repositoryName: repositoryReference.name)
                } label: {
                    HStack {
                        Label("\(repositoryReference.ownerCanonicalName)/\(repositoryReference.name)", systemImage: "book.closed")
                        Spacer()
                        if isOpeningRepository {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(isOpeningRepository)
                .themedRow()
            }
        }
    }

    @ViewBuilder
    private func debugSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if appState.isDebugModeEnabled {
            Section("Debug") {
                DebugTextBlock(
                    title: "Diagnostics",
                    content: """
                    jobId: \(job.id)
                    status: \(job.status.rawValue)
                    tasks: \(job.tasks.count)
                    artifacts: \(job.artifacts.count)
                    owner: \(job.owner.canonicalName)
                    url: \(SRHTWebURL.build(jobId: job.id, ownerCanonicalName: job.owner.canonicalName)?.absoluteString ?? "unavailable")
                    """
                )
                .themedRow()

                if let rawJobResponse = viewModel.rawJobResponse {
                    DebugTextBlock(title: "Raw Response", content: rawJobResponse)
                        .themedRow()
                }
            }
        }
    }

    @ViewBuilder
    private func detailsSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        Section("Details") {
            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    JobStatusIcon(status: job.status)
                    Text(job.status.rawValue)
                        .font(.subheadline.weight(.medium))
                }
            }
            .themedRow()

            if let note = job.note, !note.isEmpty {
                LabeledContent("Note", value: note)
                    .themedRow()
            }

            if let image = job.image {
                LabeledContent("Image", value: image)
                    .themedRow()
            }

            if !job.tags.isEmpty {
                LabeledContent("Tags", value: job.tags.joined(separator: ", "))
                    .themedRow()
            }

            if let visibility = job.visibility {
                LabeledContent("Visibility", value: visibility.rawValue.capitalized)
                    .themedRow()
            }

            LabeledContent("Owner", value: job.owner.canonicalName)
                .themedRow()
            LabeledContent("Created", value: job.created.relativeDescription)
                .themedRow()
            LabeledContent("Updated", value: job.updated.relativeDescription)
                .themedRow()
        }
    }

    @ViewBuilder
    private func cacheSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if let cacheMetadata = viewModel.cacheMetadata {
            Section {
                StaleCacheStatusRow(metadata: cacheMetadata, isRefreshing: viewModel.isRefreshingCachedData)
            }
        }
    }

    @ViewBuilder
    private func rebuildSection(_ job: JobDetail, _ viewModel: BuildDetailViewModel) -> some View {
        if let manifest = job.manifest,
           !manifest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section {
                Button {
                    Task {
                        rebuiltJobId = await viewModel.rebuildJob()
                    }
                } label: {
                    HStack {
                        Text(job.status == .failed || job.status == .cancelled || job.status == .timeout ? "Retry Build" : "Rebuild")
                        if viewModel.isRebuilding {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isRebuilding)
                .themedRow()

                Button {
                    showEditResubmitSheet = true
                } label: {
                    Text("Edit & Resubmit")
                }
                .disabled(viewModel.isSubmittingEditedBuild)
                .themedRow()
            } footer: {
                Text("Creates a new build using this job’s saved manifest, tags, note, and visibility.")
            }
        }
    }
}

private struct BuildArtifactRow: View {
    let artifact: BuildArtifact
    let onDownload: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.filename)
                    .font(.subheadline.weight(.medium))

                if artifact.path != artifact.filename {
                    Text(artifact.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                onDownload()
            } label: {
                Image(systemName: artifact.isDownloadable ? "arrow.down.circle" : "archivebox")
                    .imageScale(.large)
            }
            .disabled(!artifact.isDownloadable)
            .accessibilityLabel(artifact.isDownloadable ? "Download \(artifact.filename)" : "\(artifact.filename) is unavailable")
        }
    }

    private var metadataText: String {
        var parts = [artifact.size.formattedByteCount]
        parts.append("Created \(artifact.created.relativeDescription)")
        if !artifact.isDownloadable {
            parts.append("Unavailable")
        }
        return parts.joined(separator: " • ")
    }
}

private struct EditResubmitBuildSheet: View {
    let viewModel: BuildDetailViewModel
    let job: JobDetail
    let onSubmitted: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: BuildDraft

    init(viewModel: BuildDetailViewModel, job: JobDetail, onSubmitted: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.job = job
        self.onSubmitted = onSubmitted
        _draft = State(initialValue: BuildDraft(
            manifest: job.manifest ?? "",
            tagsText: job.tags.joined(separator: ", "),
            note: job.note ?? "",
            visibility: job.visibility ?? .publicVisibility
        ))
    }

    var body: some View {
        NavigationStack {
            BuildDraftForm(
                draft: $draft,
                manifestPlaceholder: "Build manifest",
                footnote: "This submits a new build. “Start build now” and “Allow build secrets” use local defaults because the current job does not include those original values.",
                error: viewModel.actionError
            )
            .navigationTitle("Edit & Resubmit")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                viewModel.dismissActionError()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissActionError()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if let jobId = await viewModel.submitBuild(
                                manifest: draft.manifest,
                                tags: draft.tags,
                                note: draft.note,
                                secrets: draft.secrets,
                                execute: draft.execute,
                                visibility: draft.visibility
                            ) {
                                onSubmitted(jobId)
                            }
                        }
                    } label: {
                        if viewModel.isSubmittingEditedBuild {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Submit Build")
                        }
                    }
                    .disabled(!draft.hasManifest || viewModel.isSubmittingEditedBuild)
                }
            }
            .themedList()
        }
    }
}

// MARK: - Task Status Icon

private struct TaskStatusIcon: View {
    let status: TaskStatus

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(color)
            .frame(width: 20)
    }

    private var iconName: String {
        switch status {
        case .success: "checkmark.circle.fill"
        case .failed:  "xmark.circle.fill"
        case .running: "arrow.trianglehead.2.clockwise.rotate.90"
        case .pending: "circle.dashed"
        case .skipped: "forward.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .success: .green
        case .failed:  .red
        case .running: .yellow
        case .pending: .gray
        case .skipped: .secondary
        }
    }
}
