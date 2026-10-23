import SwiftUI

/// Something that can't be undone, with what its confirmation alert says.
protocol DestructiveAction {
    var title: String { get }
    var confirmationLabel: String { get }
    var message: String { get }
}

extension View {
    /// Asks to confirm `pending` while it's set, and runs `perform` with it once confirmed.
    func destructiveConfirmation<Action: DestructiveAction>(
        _ pending: Binding<Action?>,
        perform: @escaping (Action) async -> Void
    ) -> some View {
        alert(
            pending.wrappedValue?.title ?? "",
            isPresented: .isPresent(pending)
        ) {
            Button("Cancel", role: .cancel) {
                /* Dismiss only; destructive action is separate. */
            }
            Button(pending.wrappedValue?.confirmationLabel ?? "Confirm", role: .destructive) {
                guard let action = pending.wrappedValue else { return }
                pending.wrappedValue = nil
                Task {
                    await perform(action)
                }
            }
        } message: {
            if let action = pending.wrappedValue {
                Text(action.message)
            }
        }
    }
}
