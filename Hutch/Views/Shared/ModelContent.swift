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

extension View {
    /// A + button, once `model` exists, that presents `sheet`. The sheet calls back with what it
    /// created, which closes it and pushes `destination`.
    func createFlow<Model, Item, Sheet: View, Destination: View>(
        _ model: Model?,
        label: LocalizedStringKey,
        isPresented: Binding<Bool>,
        created: Binding<Item?>,
        @ViewBuilder sheet: @escaping (Model, @escaping (Item) -> Void) -> Sheet,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        toolbar {
            if model != nil {
                AddToolbarItem(label: label) {
                    isPresented.wrappedValue = true
                }
            }
        }
        .sheet(isPresented: isPresented) {
            if let model {
                sheet(model) { item in
                    isPresented.wrappedValue = false
                    created.wrappedValue = item
                }
            }
        }
        .navigationDestination(isPresented: .isPresent(created)) {
            if let item = created.wrappedValue {
                destination(item)
            }
        }
    }
}
