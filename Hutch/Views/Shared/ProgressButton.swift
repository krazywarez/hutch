import SwiftUI

/// A full-width button that shows a spinner in place of its title while `isWorking`.
struct ProgressButton: View {
    let title: LocalizedStringKey
    let isWorking: Bool
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: LocalizedStringKey, isWorking: Bool, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isWorking = isWorking
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            if isWorking {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
