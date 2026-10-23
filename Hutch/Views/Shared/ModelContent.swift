import SwiftUI

/// A screen's content once its view model exists, and a loading state until then.
struct ModelContent<Model, Content: View>: View {
    let model: Model?
    let loadingMessage: String
    @ViewBuilder let content: (Model) -> Content

    var body: some View {
        if let model {
            content(model)
        } else {
            SRHTLoadingStateView(message: loadingMessage)
        }
    }
}

/// The + button a list adds with.
struct AddToolbarItem: ToolbarContent {
    let label: LocalizedStringKey
    var placement: ToolbarItemPlacement = .topBarTrailing
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button(action: action) {
                Image(systemName: "plus")
            }
            .accessibilityLabel(label)
        }
    }
}
