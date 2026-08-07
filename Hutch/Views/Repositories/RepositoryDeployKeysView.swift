import SwiftUI

@Observable
@MainActor
final class RepositoryDeployKeysViewModel {
    private(set) var keys: [RepositoryDeployKey] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var deletingRID: String?
    var loadError: String?
    var error: String?
    var saveError: String?

    let repositoryRid: String
    private let service: RepositoryDeployKeyService

    init(repositoryRid: String, service: RepositoryDeployKeyService) {
        self.repositoryRid = repositoryRid
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            keys = try await service.fetchDeployKeys(repositoryRid: repositoryRid)
        } catch {
            if keys.isEmpty {
                loadError = error.userFacingMessage
            } else {
                self.error = error.userFacingMessage
            }
        }
    }

    func addKey(publicKey: String, mode: AccessMode) async -> Bool {
        let trimmed = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSaving else { return false }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await service.createDeployKey(repositoryRid: repositoryRid, mode: mode, key: trimmed)
            // The create response omits the key's fields, so reload the list.
            keys = try await service.fetchDeployKeys(repositoryRid: repositoryRid)
            return true
        } catch {
            saveError = error.userFacingMessage
            return false
        }
    }

    func deleteKey(_ key: RepositoryDeployKey) async {
        guard deletingRID == nil else { return }
        deletingRID = key.rid
        error = nil
        defer { deletingRID = nil }
        do {
            try await service.deleteDeployKey(rid: key.rid)
            keys.removeAll { $0.rid == key.rid }
        } catch {
            self.error = error.userFacingMessage
        }
    }
}

struct RepositoryDeployKeysView: View {
    let repository: RepositorySummary
    let client: SRHTClient
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RepositoryDeployKeysViewModel?
    @State private var showAddSheet = false
    @State private var pendingDeletion: RepositoryDeployKey?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                SRHTLoadingStateView(message: "Loading deploy keys…")
            }
        }
        .navigationTitle("Deploy Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            if viewModel != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add deploy key")
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = RepositoryDeployKeysViewModel(
                    repositoryRid: repository.rid,
                    service: RepositoryDeployKeyService(client: client)
                )
                viewModel = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: RepositoryDeployKeysViewModel) -> some View {
        Group {
            if viewModel.isLoading, viewModel.keys.isEmpty, viewModel.loadError == nil {
                SRHTLoadingStateView(message: "Loading deploy keys…")
            } else if let loadError = viewModel.loadError, viewModel.keys.isEmpty {
                SRHTErrorStateView(
                    title: "Couldn't Load Deploy Keys",
                    message: loadError,
                    retryAction: { await viewModel.load() }
                )
            } else {
                List {
                    if viewModel.keys.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Deploy Keys",
                                systemImage: "key",
                                description: Text("Add an SSH public key to grant this repository read or read/write access for automation.")
                            )
                            .themedRow()
                        }
                    } else {
                        Section {
                            ForEach(viewModel.keys) { key in
                                DeployKeyRow(key: key, isDeleting: viewModel.deletingRID == key.rid)
                                    .themedRow()
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDeletion = key
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } footer: {
                            Text("Deploy keys are SSH keys scoped to this repository only.")
                        }
                    }
                }
                .themedList()
                .refreshable { await viewModel.load() }
            }
        }
        .srhtErrorBanner(error: Binding(get: { viewModel.error }, set: { viewModel.error = $0 }))
        .confirmationDialog(
            "Delete this deploy key?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let key = pendingDeletion {
                    pendingDeletion = nil
                    Task { await viewModel.deleteKey(key) }
                }
            }
        } message: {
            Text("This revokes the key's access to \(repository.name). This cannot be undone.")
        }
        .sheet(isPresented: $showAddSheet) {
            AddDeployKeyView(viewModel: viewModel)
        }
    }
}

private struct DeployKeyRow: View {
    let key: RepositoryDeployKey
    let isDeleting: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(key.comment?.isEmpty == false ? key.comment! : key.keyType)
                    .font(.body)
                    .lineLimit(1)
                Text(key.fingerprintSHA256)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isDeleting {
                ProgressView().controlSize(.small)
            } else {
                Text(key.access.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AddDeployKeyView: View {
    let viewModel: RepositoryDeployKeysViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var publicKey = ""
    @State private var mode: AccessMode = .ro

    var body: some View {
        NavigationStack {
            Form {
                Section("SSH Public Key") {
                    TextField("ssh-ed25519 AAAA… comment", text: $publicKey, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .themedRow()
                }
                Section {
                    Picker("Access", selection: $mode) {
                        Text("Read Only").tag(AccessMode.ro)
                        Text("Read/Write").tag(AccessMode.rw)
                    }
                    .themedRow()
                } footer: {
                    Text("Read/Write lets the key push to this repository.")
                }
                if let saveError = viewModel.saveError, !saveError.isEmpty {
                    Section {
                        Text(saveError).foregroundStyle(.red).themedRow()
                    }
                }
            }
            .themedList()
            .navigationTitle("Add Deploy Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.addKey(publicKey: publicKey, mode: mode) {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
                }
            }
        }
    }
}
