import SwiftUI

/// A settings sheet: a loading state until `model` exists, then `form` for it, with Done to dismiss.
struct SettingsSheet<Model, Form: View>: View {
    let model: Model?
    @ViewBuilder let form: (Model) -> Form

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model)
                } else {
                    SRHTLoadingStateView(message: "Loading settings…")
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
    }
}
