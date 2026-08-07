import Foundation

nonisolated struct RepositoryACLEntry: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let mode: AccessMode
    let entity: Entity
}

nonisolated extension AccessMode {
    var shortLabel: String { rawValue }

    var displayName: String {
        switch self {
        case .ro:
            "Read Only"
        case .rw:
            "Read/Write"
        }
    }
}
