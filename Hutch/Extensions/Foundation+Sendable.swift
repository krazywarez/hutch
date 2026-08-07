import Foundation

// `UserDefaults` is documented as thread-safe but is not marked `Sendable` by
// Foundation. Hutch passes it into account sessions and the various per-account
// stores, all of which need to cross concurrency boundaries. The retroactive
// unchecked conformance reflects the documented thread-safety.
extension UserDefaults: @retroactive @unchecked Sendable {}
