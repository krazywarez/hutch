import Foundation
import Testing
@testable import Hutch

@MainActor
struct HutchIntentsTests {

    @Test
    func navigationIntentsMapToCentralRoutes() {
        #expect(OpenWorkQueueIntent().route == .workQueue(scope: .all))
        #expect(OpenRecentActivityIntent().route == .recentActivity)
        #expect(OpenSystemStatusIntent().route == .systemStatus)
        #expect(OpenFailedBuildsIntent().route == .failedBuilds)
        #expect(OpenAssignedTicketsIntent().route == .workQueue(scope: .assigned))
    }

    @Test
    func checkSystemStatusReturnsOperationalWhenNoDisruption() async throws {
        let defaultsName = "HutchIntentsTests-status-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let snapshot = SystemStatusWidgetSnapshot(
            services: [
                .init(id: "git", name: "git.sr.ht", status: "Operational", requiresAttention: false),
            ],
            hasDisruption: false,
            overallStatusText: "All monitored services operational",
            bannerSummary: "",
            updatedAt: .now
        )
        SystemStatusWidgetSnapshotStore.save(snapshot, defaults: defaults)

        let loaded = SystemStatusWidgetSnapshotStore.load(defaults: defaults)
        #expect(loaded != nil)
        #expect(loaded?.hasDisruption == false)
    }

    @Test
    func checkSystemStatusReturnsDisruptionDetails() async throws {
        let defaultsName = "HutchIntentsTests-disruption-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let snapshot = SystemStatusWidgetSnapshot(
            services: [
                .init(id: "git", name: "git.sr.ht", status: "Degraded", requiresAttention: true),
                .init(id: "meta", name: "meta.sr.ht", status: "Operational", requiresAttention: false),
            ],
            hasDisruption: true,
            overallStatusText: "Experiencing disruptions",
            bannerSummary: "git.sr.ht disrupted",
            updatedAt: .now
        )
        SystemStatusWidgetSnapshotStore.save(snapshot, defaults: defaults)

        let loaded = SystemStatusWidgetSnapshotStore.load(defaults: defaults)
        #expect(loaded?.hasDisruption == true)

        let disrupted = loaded!.services.filter(\.requiresAttention)
        #expect(disrupted.count == 1)
        #expect(disrupted.first?.name == "git.sr.ht")
    }

    @Test
    func needsAttentionSnapshotSupportsBuildsCheck() {
        let defaultsName = "HutchIntentsTests-builds-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let snapshot = NeedsAttentionSnapshot(
            unreadInboxThreads: 5,
            assignedOpenTickets: 3,
            failedBuilds: 2,
            updatedAt: .now
        )
        NeedsAttentionSnapshotStore.save(snapshot, defaults: defaults)

        let loaded = NeedsAttentionSnapshotStore.load(defaults: defaults)
        #expect(loaded?.failedBuilds == 2)
        #expect(loaded?.unreadInboxThreads == 5)
        #expect(loaded?.assignedOpenTickets == 3)
    }

    @Test
    func needsAttentionSnapshotsAreIsolatedPerAccount() {
        let defaultsName = "HutchIntentsTests-builds-isolation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let firstSnapshot = NeedsAttentionSnapshot(
            unreadInboxThreads: 1,
            assignedOpenTickets: 2,
            failedBuilds: 3,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let secondSnapshot = NeedsAttentionSnapshot(
            unreadInboxThreads: 8,
            assignedOpenTickets: 5,
            failedBuilds: 1,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        NeedsAttentionSnapshotStore.save(firstSnapshot, accountID: "account-a", defaults: defaults)
        NeedsAttentionSnapshotStore.save(secondSnapshot, accountID: "account-b", defaults: defaults)

        #expect(NeedsAttentionSnapshotStore.load(accountID: "account-a", defaults: defaults)?.unreadInboxThreads == 1)
        #expect(NeedsAttentionSnapshotStore.load(accountID: "account-b", defaults: defaults)?.unreadInboxThreads == 8)

        ActiveAccountContextStore.save("account-a", defaults: defaults)
        #expect(NeedsAttentionSnapshotStore.load(defaults: defaults)?.failedBuilds == 3)
    }

    @Test
    func searchIntentCarriesQueryAndType() {
        let intent = SearchHutchIntent()
        intent.query = "~alice/hutch"
        intent.searchType = .tracker
        #expect(intent.route == .search(query: "~alice/hutch", type: .tracker))
    }

    @Test
    func searchIntentWithBlankQueryFallsBackToLookup() {
        let intent = SearchHutchIntent()
        intent.query = "   "
        intent.searchType = .user
        #expect(intent.route == .lookup)
    }

    @Test
    func removePinDropsMatchingResource() {
        let defaultsName = "HutchIntentsTests-unpin-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let alice = HomePinRecord(kind: .user, value: "~alice", title: "~alice", subtitle: "User", ownerUsername: "~alice", service: nil)
        let bob = HomePinRecord(kind: .user, value: "~bob", title: "~bob", subtitle: "User", ownerUsername: "~bob", service: nil)
        HomePinStore.togglePin(alice, for: "~me", defaults: defaults)
        HomePinStore.togglePin(bob, for: "~me", defaults: defaults)

        HomePinStore.removePin(id: alice.id, for: "~me", defaults: defaults)

        let remaining = HomePinStore.loadPins(for: "~me", defaults: defaults)
        #expect(remaining.map(\.id) == [bob.id])
    }
}
