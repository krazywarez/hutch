import SwiftUI

extension Binding where Value == Bool {
    /// True while `item` holds a value; dismissing clears it. Presents a
    /// dialog or alert about whatever `item` names.
    static func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
