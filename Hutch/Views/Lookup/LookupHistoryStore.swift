import Foundation

struct LookupHistoryEntry: Codable, Hashable, Identifiable, Sendable {
    let type: LookupType
    let query: String
    let createdAt: Date

    var id: String {
        "\(type.rawValue):\(query)"
    }
}

enum LookupHistoryStore {
    private static let maximumEntries = 20

    static func load(defaults: UserDefaults = .standard) -> [LookupHistoryEntry] {
        guard let data = defaults.data(forKey: AppStorageKeys.lookupHistory) else {
            return []
        }

        do {
            return try JSONDecoder().decode([LookupHistoryEntry].self, from: data)
        } catch {
            defaults.removeObject(forKey: AppStorageKeys.lookupHistory)
            return []
        }
    }

    static func record(
        type: LookupType,
        query: String,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return }

        var entries = load(defaults: defaults)
        entries.removeAll { $0.type == type && $0.query == normalizedQuery }
        entries.insert(
            LookupHistoryEntry(type: type, query: normalizedQuery, createdAt: now),
            at: 0
        )

        if entries.count > maximumEntries {
            entries = Array(entries.prefix(maximumEntries))
        }

        save(entries, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: AppStorageKeys.lookupHistory)
    }

    private static func save(_ entries: [LookupHistoryEntry], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: AppStorageKeys.lookupHistory)
    }
}
