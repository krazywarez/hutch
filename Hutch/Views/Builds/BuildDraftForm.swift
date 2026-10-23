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
