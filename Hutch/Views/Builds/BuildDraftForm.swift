import SwiftUI

/// A build about to be submitted: its manifest and the options it runs with.
struct BuildDraft {
    var manifest = ""
    var tagsText = ""
    var note = ""
    var secrets = false
    var execute = true
    var visibility: Visibility = .publicVisibility

    /// The comma-separated tags, trimmed, without empties.
    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasManifest: Bool {
        !manifest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The fields of a build submission, with a note under them and the last error, if any.
struct BuildDraftForm: View {
    @Binding var draft: BuildDraft
    let manifestPlaceholder: String
    let footnote: String
    let error: String?

    var body: some View {
        Form {
            Section("Build Manifest") {
                TextField(manifestPlaceholder, text: $draft.manifest, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(12...24)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .themedRow()
            }

            Section("Build Options") {
                TextField("Note (optional)", text: $draft.note)
                    .themedRow()
                TextField("Tags (comma-separated, optional)", text: $draft.tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .themedRow()
                Picker("Visibility", selection: $draft.visibility) {
                    Text("Public").tag(Visibility.publicVisibility)
                    Text("Unlisted").tag(Visibility.unlisted)
                    Text("Private").tag(Visibility.privateVisibility)
                }
                .themedRow()
                Toggle("Start build now", isOn: $draft.execute)
                    .themedRow()
                Toggle("Allow build secrets", isOn: $draft.secrets)
                    .themedRow()
            }

            Section {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .themedRow()
            }

            if let error {
                Section {
                    Label {
                        Text(error)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .foregroundStyle(.red)
                    .themedRow()
                }
            }
        }
    }
}

/// Something a build draft can be submitted to, answering the new job's id.
@MainActor
protocol BuildSubmitting {
    func submitBuild(
        manifest: String,
        tags: [String],
        note: String,
        secrets: Bool,
        execute: Bool,
        visibility: Visibility
    ) async -> Int?
}

extension BuildListViewModel: BuildSubmitting {}
extension BuildDetailViewModel: BuildSubmitting {}

/// Cancel, and Submit Build once the draft has a manifest.
struct BuildDraftToolbar: ToolbarContent {
    let draft: BuildDraft
    let submitter: any BuildSubmitting
    let isSubmitting: Bool
    let cancel: () -> Void
    let onSubmitted: (Int) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    if let jobId = await submitter.submitBuild(
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
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Submit Build")
                }
            }
            .disabled(!draft.hasManifest || isSubmitting)
        }
    }
}
