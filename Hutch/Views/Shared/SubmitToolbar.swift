import SwiftUI

/// Cancel, and a confirm button that shows a spinner in place of its title while `isWorking`.
struct SubmitToolbar: ToolbarContent {
    let title: LocalizedStringKey
    let isWorking: Bool
    let isDisabled: Bool
    let cancel: () -> Void
    let submit: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: cancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: submit) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(title)
                }
            }
            .disabled(isDisabled)
        }
    }
}
