import SwiftUI

/// The red Delete swipe action.
struct SwipeDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
}

/// The blue Edit swipe action.
struct SwipeEditButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }
}
