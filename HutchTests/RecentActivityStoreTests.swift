import Foundation
import Testing
@testable import Hutch

@MainActor
struct RecentActivityStoreTests {
    @Test
    func removeDropsMatchingEntryKeepingOthers() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        RecentActivityStore.recordBuild(jobId: 1, title: "Build 1", defaults: defaults)
        RecentActivityStore.recordBuild(jobId: 2, title: "Build 2", defaults: defaults)

        RecentActivityStore.remove(id: "build:1", defaults: defaults)

        let remaining = RecentActivityStore.load(defaults: defaults)
        #expect(remaining.map(\.id) == ["build:2"])
    }

    @Test
    func clearRemovesAllEntries() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        RecentActivityStore.recordBuild(jobId: 1, title: "Build 1", defaults: defaults)
        RecentActivityStore.recordTicket(
            ownerUsername: "~alice",
            trackerName: "hutch",
            ticketId: 42,
            title: "A ticket",
            defaults: defaults
        )

        RecentActivityStore.clear(defaults: defaults)

        #expect(RecentActivityStore.load(defaults: defaults).isEmpty)
    }
}
