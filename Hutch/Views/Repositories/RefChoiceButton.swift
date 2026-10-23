import SwiftUI

/// A branch, tag or bookmark to browse at, checked when it's the one shown.
struct RefChoiceButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isSelected: Bool
    let choose: () async -> Void

    var body: some View {
        Button {
            Task { await choose() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)

                Text(title)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
