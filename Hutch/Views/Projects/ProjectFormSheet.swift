import SwiftUI

/// Shared create/edit form for hub.sr.ht projects. The parent owns the save
/// state and performs the mutation via `onSave`, dismissing on success.
struct ProjectFormSheet: View {
    let title: String
    let confirmationTitle: String
    let isSaving: Bool
    let error: String?
    /// `createProject` takes no website; only the edit flow shows the field.
    let includeWebsite: Bool
    let onSave: (ProjectFormValues) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var website: String
    @State private var tags: String
    @State private var visibility: Visibility

    init(
        title: String,
        confirmationTitle: String,
        isSaving: Bool,
        error: String?,
        includeWebsite: Bool,
        initialName: String = "",
        initialDescription: String = "",
        initialWebsite: String = "",
        initialTags: [String] = [],
        initialVisibility: Visibility = .publicVisibility,
        onSave: @escaping (ProjectFormValues) async -> Bool
    ) {
        self.title = title
        self.confirmationTitle = confirmationTitle
        self.isSaving = isSaving
        self.error = error
        self.includeWebsite = includeWebsite
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _description = State(initialValue: initialDescription)
        _website = State(initialValue: initialWebsite)
        _tags = State(initialValue: initialTags.joined(separator: ", "))
        _visibility = State(initialValue: initialVisibility)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .themedRow()
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .themedRow()
                    if includeWebsite {
                        TextField("Website (optional)", text: $website)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .themedRow()
                    }
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag(Visibility.publicVisibility)
                        Text("Unlisted").tag(Visibility.unlisted)
                        Text("Private").tag(Visibility.privateVisibility)
                    }
                    .themedRow()
                }

                Section {
                    TextField("Tags (comma separated)", text: $tags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .themedRow()
                } footer: {
                    Text("Separate tags with commas.")
                }

                if let error, !error.isEmpty {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .themedRow()
                    }
                }
            }
            .themedList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let values = ProjectFormValues(
                                name: trimmedName,
                                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                                visibility: visibility,
                                tags: Self.parseTags(tags)
                            )
                            if await onSave(values) {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(confirmationTitle)
                        }
                    }
                    .disabled(trimmedName.isEmpty || isSaving)
                }
            }
        }
    }

    static func parseTags(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

struct ProjectFormValues: Sendable {
    let name: String
    let description: String
    let website: String
    let visibility: Visibility
    let tags: [String]
}
