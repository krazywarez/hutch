import SwiftUI

/// The segmented tab bar across the top of a detail screen, with a divider under it.
struct SegmentedTabs<Tab: CaseIterable & Hashable & RawRepresentable<String>>: View where Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab

    var body: some View {
        Picker("Tab", selection: $selection) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)

        Divider()
    }
}
