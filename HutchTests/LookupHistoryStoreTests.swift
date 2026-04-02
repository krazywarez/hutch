import Foundation
import Testing
@testable import Hutch

struct LookupHistoryStoreTests {

    @Test
    func recordsMostRecentUniqueSearchFirst() {
        let suiteName = "LookupHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        LookupHistoryStore.record(
            type: .user,
            query: "~alice",
            defaults: defaults,
            now: Date(timeIntervalSince1970: 100)
        )
        LookupHistoryStore.record(
            type: .gitRepo,
            query: "~alice/hutch",
            defaults: defaults,
            now: Date(timeIntervalSince1970: 200)
        )
        LookupHistoryStore.record(
            type: .user,
            query: "~alice",
            defaults: defaults,
            now: Date(timeIntervalSince1970: 300)
        )

        let history = LookupHistoryStore.load(defaults: defaults)

        #expect(history.count == 2)
        #expect(history.map(\.type) == [.user, .gitRepo])
        #expect(history.map(\.query) == ["~alice", "~alice/hutch"])
        #expect(history.first?.createdAt == Date(timeIntervalSince1970: 300))
    }

    @Test
    func trimsHistoryToMaximumSize() {
        let suiteName = "LookupHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for index in 0..<25 {
            LookupHistoryStore.record(
                type: .buildJob,
                query: "\(index)",
                defaults: defaults,
                now: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let history = LookupHistoryStore.load(defaults: defaults)

        #expect(history.count == 20)
        #expect(history.first?.query == "24")
        #expect(history.last?.query == "5")
    }

    @Test
    func clearsPersistedHistory() {
        let suiteName = "LookupHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        LookupHistoryStore.record(type: .tracker, query: "~owner/todo", defaults: defaults)
        #expect(!LookupHistoryStore.load(defaults: defaults).isEmpty)

        LookupHistoryStore.clear(defaults: defaults)

        #expect(LookupHistoryStore.load(defaults: defaults).isEmpty)
    }
}
