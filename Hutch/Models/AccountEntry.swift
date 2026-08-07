import Foundation

/// A stored sr.ht account (token + resolved username).
nonisolated struct AccountEntry: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var username: String
    var token: String
}
