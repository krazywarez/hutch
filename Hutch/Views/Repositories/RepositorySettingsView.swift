import SwiftUI

struct RepositorySettingsView: View {
    let repository: RepositorySummary
    let branches: [Reference]
    let client: SRHTClient
    let onRenamed: (String) -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RepositorySettingsViewModel?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsForm(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = RepositorySettingsViewModel(
                    repository: repository,
                    branches: branches,
                    client: client
                )
                viewModel = vm
                await vm.loadACLs()
            }
        }
    }

    @ViewBuilder
    private func settingsForm(_ viewModel: RepositorySettingsViewModel) -> some View {
        @Bindable var vm = viewModel

        Form {
            infoSection(viewModel)
            renameSection(viewModel)
            accessSection(viewModel)
            deleteSection(viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert(
            "Permanently delete \(repository.owner.canonicalName)/\(repository.name)?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRepository()
                    if viewModel.didDelete {
                        dismiss()
                        onDeleted()
                    }
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(_ viewModel: RepositorySettingsViewModel) -> some View {
        Section("Info") {
            TextField("Description", text: Bindable(viewModel).editedDescription, axis: .vertical)
                .lineLimit(3...6)

            Picker("Visibility", selection: Bindable(viewModel).editedVisibility) {
                Text("Public").tag(Visibility.public)
                Text("Unlisted").tag(Visibility.unlisted)
                Text("Private").tag(Visibility.private)
            }

            if !viewModel.branches.isEmpty {
                Picker("Default Branch", selection: Bindable(viewModel).editedHead) {
                    ForEach(viewModel.branches, id: \.name) { branch in
                        let name = branch.name.replacingOccurrences(of: "refs/heads/", with: "")
                        Text(name).tag(name)
                    }
                }
            }

            Button {
                Task { await viewModel.saveInfo() }
            } label: {
                if viewModel.isSavingInfo {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSavingInfo)
        }
    }

    // MARK: - Rename Section

    @ViewBuilder
    private func renameSection(_ viewModel: RepositorySettingsViewModel) -> some View {
        Section {
            TextField("Repository Name", text: Bindable(viewModel).editedName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Text("This will change the repository URL. Existing clones will be redirected but links may break.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await viewModel.rename()
                    if let newName = viewModel.updatedName {
                        onRenamed(newName)
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isRenaming {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Rename")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isRenaming || viewModel.editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("Rename")
        }
    }

    // MARK: - Access Section

    @ViewBuilder
    private func accessSection(_ viewModel: RepositorySettingsViewModel) -> some View {
        Section {
            if viewModel.isLoadingACLs {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.acls.isEmpty {
                Text("No access control entries.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.acls) { entry in
                    HStack {
                        Text(entry.entity.canonicalName)
                        Spacer()
                        Text(entry.mode)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteACL(entry) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            // Add ACL form
            HStack {
                TextField("Username", text: Bindable(viewModel).newACLEntity)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Picker("", selection: Bindable(viewModel).newACLMode) {
                    Text("RO").tag("RO")
                    Text("RW").tag("RW")
                }
                .pickerStyle(.segmented)
                .frame(width: 100)

                Button {
                    Task { await viewModel.addACL() }
                } label: {
                    if viewModel.isAddingACL {
                        ProgressView()
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .disabled(viewModel.isAddingACL || viewModel.newACLEntity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Access")
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private func deleteSection(_ viewModel: RepositorySettingsViewModel) -> some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                if viewModel.isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Delete Repository")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isDeleting)
        }
    }
}
