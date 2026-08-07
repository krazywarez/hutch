import SwiftUI

private struct ProjectMailingListThreadsResponse: Decodable, Sendable {
    let list: ProjectMailingListThreads
}

private struct ProjectMailingListThreads: Decodable, Sendable {
    let threads: ProjectMailingListThreadPage
}

private struct ProjectMailingListThreadPage: Decodable, Sendable {
    let results: [ProjectMailingListThreadPayload]
}

private struct ProjectMailingListThreadPayload: Decodable, Sendable {
    let updated: Date
    let subject: String
    let replies: Int
    let sender: Entity
    let root: ProjectMailingListRootPayload
}

private struct ProjectMailingListRootPayload: Decodable, Sendable {
    let id: Int
    let messageID: String
    let patch: InboxPatchPreview?
    /// Null unless the thread's root email opens a patchset. `MailingList` has no
    /// patchsets field, so this is the only way to enumerate a list's patchsets.
    let patchset: PatchsetSummaryPayload?
}

private struct PatchsetSummaryPayload: Decodable, Sendable {
    let id: Int
    let subject: String
    let version: Int
    let prefix: String?
    let status: PatchsetStatus
}

private struct ListMetaResponse: Decodable, Sendable {
    let list: ListMetaPayload?
}

private struct ListMetaPayload: Decodable, Sendable {
    let id: Int
    let owner: Entity
}

private struct SubscriptionRidsResponse: Decodable, Sendable {
    let subscriptions: SubscriptionRidsPage
}

private struct SubscriptionRidsPage: Decodable, Sendable {
    let results: [SubscriptionRidEntry]
    let cursor: String?
}

private struct SubscriptionRidEntry: Decodable, Sendable {
    let list: SubscriptionRidList?
}

private struct SubscriptionRidList: Decodable, Sendable {
    let rid: String
}

/// Toggle mutations return the subscription (nullable on unsubscribe); only
/// success matters.
private struct SubscriptionToggleResponse: Decodable, Sendable {}

@Observable
@MainActor
final class MailingListDetailViewModel {
    private(set) var threads: [InboxThreadSummary] = []
    /// Patchsets on this list, derived from thread roots — see the query below.
    private(set) var patchsets: [PatchsetSummary] = []
    private(set) var isLoading = false
    var error: String?
    var searchText = ""

    /// Subscription state. `isSubscribed` is `nil` while unknown or unavailable
    /// (the toggle stays hidden); `isOwnList` hides it for lists you own.
    private(set) var listNumericID: Int?
    private(set) var isSubscribed: Bool?
    private(set) var isOwnList = false
    private(set) var isTogglingSubscription = false

    private let mailingList: InboxMailingListReference
    private let client: SRHTClient
    private let defaults: UserDefaults
    private let accountID: String

    private static let listThreadsQuery = """
    query projectMailingListThreads($rid: ID!) {
        list(rid: $rid) {
            threads {
                results {
                    updated
                    subject
                    replies
                    sender { canonicalName }
                    root {
                        id
                        messageID
                        patch { subject }
                        patchset {
                            id
                            subject
                            version
                            prefix
                            status
                        }
                    }
                }
            }
        }
    }
    """

    init(mailingList: InboxMailingListReference, client: SRHTClient, defaults: UserDefaults, accountID: String) {
        self.mailingList = mailingList
        self.client = client
        self.defaults = defaults
        self.accountID = accountID
    }

    // MARK: - Subscription

    private static let listMetaQuery = """
    query listMeta($rid: ID!) {
        list(rid: $rid) { id owner { canonicalName } }
    }
    """

    // `MailingList.subscription` is unreliable (see the API-traps note), so
    // subscribe state comes from the authoritative `subscriptions` query.
    private static let subscriptionRidsQuery = """
    query subscriptionRids($cursor: Cursor) {
        subscriptions(cursor: $cursor) {
            results {
                ... on MailingListSubscription { list { rid } }
            }
            cursor
        }
    }
    """

    private static let subscribeMutation = """
    mutation mailingListSubscribe($id: Int!) {
        mailingListSubscribe(listID: $id) { id }
    }
    """

    private static let unsubscribeMutation = """
    mutation mailingListUnsubscribe($id: Int!) {
        mailingListUnsubscribe(listID: $id) { id }
    }
    """

    /// Resolves the list's numeric id, whether the viewer owns it, and — for
    /// lists they don't own — whether they're subscribed.
    func loadSubscriptionState(currentUserCanonicalName: String?) async {
        do {
            let meta = try await client.execute(
                service: .lists,
                query: Self.listMetaQuery,
                variables: ["rid": mailingList.rid],
                responseType: ListMetaResponse.self
            )
            guard let list = meta.list else { return }
            listNumericID = list.id

            if let currentUserCanonicalName, list.owner.canonicalName == currentUserCanonicalName {
                isOwnList = true
                return
            }
            isSubscribed = try await isSubscribed(toRid: mailingList.rid)
        } catch {
            // Leave state unknown; the toggle stays hidden rather than lying.
        }
    }

    private func isSubscribed(toRid rid: String) async throws -> Bool {
        var cursor: String?
        repeat {
            let response = try await client.execute(
                service: .lists,
                query: Self.subscriptionRidsQuery,
                variables: cursor.map { ["cursor": $0] },
                responseType: SubscriptionRidsResponse.self
            )
            if response.subscriptions.results.contains(where: { $0.list?.rid == rid }) {
                return true
            }
            cursor = response.subscriptions.cursor
        } while cursor != nil
        return false
    }

    func toggleSubscription() async {
        guard let id = listNumericID, let subscribed = isSubscribed, !isTogglingSubscription else { return }
        isTogglingSubscription = true
        defer { isTogglingSubscription = false }
        do {
            _ = try await client.execute(
                service: .lists,
                query: subscribed ? Self.unsubscribeMutation : Self.subscribeMutation,
                variables: ["id": id],
                responseType: SubscriptionToggleResponse.self
            )
            isSubscribed = !subscribed
        } catch {
            self.error = error.userFacingMessage
        }
    }

    var filteredThreads: [InboxThreadSummary] {
        Self.filterThreads(threads, matching: searchText)
    }

    func loadThreads() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.execute(
                service: .lists,
                query: Self.listThreadsQuery,
                variables: ["rid": mailingList.rid],
                responseType: ProjectMailingListThreadsResponse.self
            )

            let activity = await MailingListActivityLoader.load(
                client: client,
                listRID: mailingList.rid,
                since: InboxReadStateStore.baseline(defaults: defaults) ?? .distantPast
            )

            threads = deduplicateThreads(
                response.list.threads.results.map { makeSummary(from: $0, activity: activity) }
            )
            patchsets = Self.patchsets(from: response.list.threads.results)
        } catch {
            self.error = "Failed to load mailing list"
        }
    }

    var filteredPatchsets: [PatchsetSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return patchsets }
        return patchsets.filter { $0.subject.lowercased().contains(query) }
    }

    /// Collects the patchsets opened by these threads, newest first.
    ///
    /// A revised series arrives as its own thread, so the same subject can appear
    /// at several versions; they are kept as distinct patchsets and the version
    /// chain is shown in the detail view.
    private nonisolated static func patchsets(
        from threads: [ProjectMailingListThreadPayload]
    ) -> [PatchsetSummary] {
        var seenIDs = Set<Int>()
        var results: [PatchsetSummary] = []

        for thread in threads {
            guard let payload = thread.root.patchset, !seenIDs.contains(payload.id) else { continue }
            seenIDs.insert(payload.id)
            results.append(
                PatchsetSummary(
                    id: payload.id,
                    subject: payload.subject,
                    version: payload.version,
                    prefix: payload.prefix,
                    status: payload.status
                )
            )
        }

        return results
    }

    func markThreadRead(_ thread: InboxThreadSummary) {
        let viewedAt = max(Date(), thread.lastActivityAt)
        InboxReadStateStore.markViewed(viewedAt, for: thread.threadGroupingKey, defaults: defaults)
        updateThread(thread, isUnread: false)
        NeedsAttentionSnapshotStore.adjustUnreadInboxThreads(by: -1, accountID: accountID)
    }

    func markThreadUnread(_ thread: InboxThreadSummary) {
        InboxReadStateStore.markUnread(for: thread.threadGroupingKey, defaults: defaults)
        updateThread(thread, isUnread: true)
        NeedsAttentionSnapshotStore.adjustUnreadInboxThreads(by: 1, accountID: accountID)
    }

    func markAllThreadsRead() {
        let unreadThreads = threads.filter(\.isUnread)
        guard !unreadThreads.isEmpty else { return }

        let viewedAt = Date()
        for thread in unreadThreads {
            InboxReadStateStore.markViewed(max(viewedAt, thread.lastActivityAt), for: thread.threadGroupingKey, defaults: defaults)
        }

        threads = threads.map { thread in
            guard thread.isUnread else { return thread }
            return InboxThreadSummary(
                rootEmailID: thread.rootEmailID,
                rootMessageID: thread.rootMessageID,
                threadRootEmailIDs: thread.threadRootEmailIDs,
                threadRootMessageIDs: thread.threadRootMessageIDs,
                listID: thread.listID,
                listRID: thread.listRID,
                listName: thread.listName,
                listOwner: thread.listOwner,
                subject: thread.subject,
                latestSender: thread.latestSender,
                lastActivityAt: thread.lastActivityAt,
                messageCount: thread.messageCount,
                repo: thread.repo,
                containsPatch: thread.containsPatch,
                isUnread: false
            )
        }

        NeedsAttentionSnapshotStore.adjustUnreadInboxThreads(by: -unreadThreads.count, accountID: accountID)
    }

    private func makeSummary(
        from thread: ProjectMailingListThreadPayload,
        activity: MailingListActivity
    ) -> InboxThreadSummary {
        let normalizedSubject = thread.subject
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^(?:(?:re|fwd?)\s*:\s*)+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .lowercased()
        let threadID = "\(mailingList.rid)#\(normalizedSubject)"

        // thread.updated is the root email's insert time and never advances when a
        // reply lands, so activity has to come from the list's mail feed.
        let lastActivityAt = activity.lastActivity(rootEmailID: thread.root.id, fallback: thread.updated)

        return InboxThreadSummary(
            rootEmailID: thread.root.id,
            rootMessageID: thread.root.messageID,
            threadRootEmailIDs: [thread.root.id],
            threadRootMessageIDs: [thread.root.messageID],
            listID: 0,
            listRID: mailingList.rid,
            listName: mailingList.name,
            listOwner: mailingList.owner,
            subject: thread.subject,
            latestSender: thread.sender,
            lastActivityAt: lastActivityAt,
            messageCount: thread.replies + 1,
            repo: nil,
            containsPatch: thread.root.patch != nil || thread.subject.localizedCaseInsensitiveContains("[patch"),
            isUnread: InboxReadStateStore.isUnread(threadID: threadID, lastActivityAt: lastActivityAt, defaults: defaults)
        )
    }

    private func updateThread(_ thread: InboxThreadSummary, isUnread: Bool) {
        guard let index = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        let current = threads[index]
        threads[index] = InboxThreadSummary(
            rootEmailID: current.rootEmailID,
            rootMessageID: current.rootMessageID,
            threadRootEmailIDs: current.threadRootEmailIDs,
            threadRootMessageIDs: current.threadRootMessageIDs,
            listID: current.listID,
            listRID: current.listRID,
            listName: current.listName,
            listOwner: current.listOwner,
            subject: current.subject,
            latestSender: current.latestSender,
            lastActivityAt: current.lastActivityAt,
            messageCount: current.messageCount,
            repo: current.repo,
            containsPatch: current.containsPatch,
            isUnread: isUnread
        )
    }

    private func deduplicateThreads(_ threads: [InboxThreadSummary]) -> [InboxThreadSummary] {
        var grouped: [String: InboxThreadSummary] = [:]

        for thread in threads {
            guard let existing = grouped[thread.threadGroupingKey] else {
                grouped[thread.threadGroupingKey] = thread
                continue
            }

            let latest = thread.lastActivityAt >= existing.lastActivityAt ? thread : existing
            let mergedRootEmailIDs = Array(Set(existing.threadRootEmailIDs + thread.threadRootEmailIDs)).sorted()
            let mergedRootMessageIDs = Array(Set(existing.threadRootMessageIDs + thread.threadRootMessageIDs)).sorted()
            let mergedMessageCount = max(
                existing.messageCount ?? existing.threadRootMessageIDs.count,
                thread.messageCount ?? thread.threadRootMessageIDs.count,
                mergedRootMessageIDs.count
            )

            grouped[thread.threadGroupingKey] = InboxThreadSummary(
                rootEmailID: latest.rootEmailID,
                rootMessageID: latest.rootMessageID,
                threadRootEmailIDs: mergedRootEmailIDs,
                threadRootMessageIDs: mergedRootMessageIDs,
                listID: latest.listID,
                listRID: latest.listRID,
                listName: latest.listName,
                listOwner: latest.listOwner,
                subject: latest.subject,
                latestSender: latest.latestSender,
                lastActivityAt: max(existing.lastActivityAt, thread.lastActivityAt),
                messageCount: mergedMessageCount,
                repo: latest.repo ?? existing.repo,
                containsPatch: latest.containsPatch || existing.containsPatch,
                isUnread: latest.isUnread || existing.isUnread
            )
        }

        return grouped.values.sorted { lhs, rhs in
            if lhs.lastActivityAt == rhs.lastActivityAt {
                return lhs.displaySubject.localizedCaseInsensitiveCompare(rhs.displaySubject) == .orderedAscending
            }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }

    nonisolated static func filterThreads(
        _ threads: [InboxThreadSummary],
        matching query: String
    ) -> [InboxThreadSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return threads }
        return threads.filter {
            normalizedSubject(from: $0.subject).contains(q) ||
            $0.latestSender.canonicalName.lowercased().contains(q)
        }
    }

    private nonisolated static func normalizedSubject(from subject: String) -> String {
        subject
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^(?:(?:re|fwd?)\s*:\s*)+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .lowercased()
    }
}

enum MailingListScope: String, CaseIterable, Hashable {
    case threads
    case patches

    var displayName: String {
        switch self {
        case .threads: "Threads"
        case .patches: "Patches"
        }
    }
}

struct MailingListDetailView: View {
    let mailingList: InboxMailingListReference

    @Environment(AppState.self) private var appState
    @State private var viewModel: MailingListDetailViewModel?
    @State private var pinChangeCount = 0
    @State private var scope: MailingListScope = .threads

    private var currentUserKey: String? {
        appState.currentUser?.canonicalName
    }

    private var isPinnedToHome: Bool {
        _ = pinChangeCount
        guard let currentUserKey else { return false }
        return HomePinStore.isPinned(.mailingList(mailingList), for: currentUserKey, defaults: appState.accountDefaults)
    }

    private var hasUnreadThreads: Bool {
        viewModel?.threads.contains(where: \.isUnread) == true
    }

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                SRHTLoadingStateView(message: "Loading mailing list…")
            }
        }
        .navigationTitle(mailingList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Mark All Read") {
                    viewModel?.markAllThreadsRead()
                }
                .disabled(hasUnreadThreads == false)
            }
            if currentUserKey != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        togglePinnedState()
                    } label: {
                        Image(systemName: isPinnedToHome ? "pin.fill" : "pin")
                    }
                    .accessibilityLabel(isPinnedToHome ? "Unpin from Home" : "Pin to Home")
                }
            }
            if let viewModel, !viewModel.isOwnList, let subscribed = viewModel.isSubscribed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.toggleSubscription() }
                    } label: {
                        if viewModel.isTogglingSubscription {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: subscribed ? "bell.fill" : "bell")
                        }
                    }
                    .disabled(viewModel.isTogglingSubscription)
                    .accessibilityLabel(subscribed ? "Unsubscribe from list" : "Subscribe to list")
                }
            }
        }
        .task {
            if viewModel == nil {
                let viewModel = MailingListDetailViewModel(
                    mailingList: mailingList,
                    client: appState.client,
                    defaults: appState.accountDefaults,
                    accountID: appState.activeAccountID
                )
                self.viewModel = viewModel
                await viewModel.loadThreads()
                await viewModel.loadSubscriptionState(currentUserCanonicalName: currentUserKey)
            }
        }
        .onAppear {
            guard let viewModel else { return }
            Task {
                await viewModel.loadThreads()
            }
        }
    }

    private func togglePinnedState() {
        guard let currentUserKey else { return }
        HomePinStore.togglePin(.mailingList(mailingList), for: currentUserKey, defaults: appState.accountDefaults)
        pinChangeCount += 1
    }

    @ViewBuilder
    private func content(_ viewModel: MailingListDetailViewModel) -> some View {
        @Bindable var vm = viewModel

        List {
            // Only offered when the list actually carries patches, so discussion
            // lists do not grow an empty tab.
            if !viewModel.patchsets.isEmpty {
                Picker("Scope", selection: $scope) {
                    ForEach(MailingListScope.allCases, id: \.self) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .themedRow()
            }

            if showingPatches(viewModel) {
                ForEach(viewModel.filteredPatchsets) { patchset in
                    // Pushed directly rather than by value: this view is also shown
                    // from a project, whose stack declares no MoreRoute destination.
                    NavigationLink {
                        PatchsetDetailView(patchsetID: patchset.id, listName: mailingList.name)
                    } label: {
                        PatchsetRow(patchset: patchset)
                    }
                    .themedRow()
                }
            } else {
            ForEach(viewModel.filteredThreads) { thread in
                NavigationLink {
                    ThreadDetailView(
                        thread: thread,
                        onViewed: {
                            viewModel.markThreadRead(thread)
                        },
                        onMarkRead: {
                            viewModel.markThreadRead(thread)
                        },
                        onMarkUnread: {
                            viewModel.markThreadUnread(thread)
                        }
                    )
                } label: {
                    InboxThreadRow(thread: thread)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if thread.isUnread {
                                viewModel.markThreadRead(thread)
                            } else {
                                viewModel.markThreadUnread(thread)
                            }
                        }
                    } label: {
                        Label(
                            thread.isUnread ? "Mark as Read" : "Mark as Unread",
                            systemImage: thread.isUnread ? "envelope.open" : "envelope.badge"
                        )
                    }
                    .tint(thread.isUnread ? .blue : .gray)
                }
            }
            .themedRow()
            }
        }
        .themedList()
        .listStyle(.plain)
        .searchable(
            text: $vm.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: showingPatches(viewModel) ? "Search patches" : "Search messages"
        )
        .overlay {
            if viewModel.isLoading, viewModel.threads.isEmpty {
                SRHTLoadingStateView(message: "Loading mailing list…")
            } else if let error = viewModel.error, viewModel.threads.isEmpty {
                SRHTErrorStateView(
                    title: "Couldn't Load Mailing List",
                    message: error,
                    retryAction: { await viewModel.loadThreads() }
                )
            } else if showingPatches(viewModel) {
                if !viewModel.patchsets.isEmpty, viewModel.filteredPatchsets.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else if !viewModel.threads.isEmpty, viewModel.filteredThreads.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if viewModel.threads.isEmpty {
                ContentUnavailableView(
                    "No Threads",
                    systemImage: "tray",
                    description: Text("This mailing list does not have any recent threads.")
                )
            }
        }
        .refreshable {
            await viewModel.loadThreads()
        }
        .srhtErrorBanner(error: $vm.error)
    }

    private func showingPatches(_ viewModel: MailingListDetailViewModel) -> Bool {
        scope == .patches && !viewModel.patchsets.isEmpty
    }
}

struct PatchsetRow: View {
    let patchset: PatchsetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(patchset.subject)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 8) {
                PatchsetStatusBadge(status: patchset.status)
                if let versionLabel = patchset.versionLabel {
                    Text(versionLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patchset.subject), \(patchset.status.displayName)")
    }
}

struct ProjectMailingListView: View {
    let mailingList: Project.MailingList

    var body: some View {
        MailingListDetailView(mailingList: mailingList.inboxReference)
    }
}
