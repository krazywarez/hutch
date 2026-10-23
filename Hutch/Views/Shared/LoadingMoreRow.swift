import SwiftUI

/// The spinner at the foot of a list while its next page loads.
struct LoadingMoreRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}
