# feat: User resource browsing from profile

## Goal

Extend `UserProfileView` so that after looking up a user, their public
repositories and trackers are shown as browsable sections below the existing
profile metadata. This mirrors the sr.ht `~username` page.

---

## Context

**Entry point:** `Hutch/Views/Lookup/LookupView.swift`
Looking up a user opens `UserProfileView` in a sheet. Currently the view only
shows static metadata fields from the `User` model.

**Owner identifier:** `user.canonicalName` (e.g. `~username`). Strip the leading
`~` when passing to GraphQL `username` parameters — see the existing pattern in
`AppState.resolveRepository(owner:name:)`.

**Existing row views to reuse:**
- `RepositoryRowView` in `Hutch/Views/Repositories/RepositoryRowView.swift`
- Tracker row style from `TrackerListView` private `TrackerRowView`

**API pattern for user-scoped queries** (from `AppState.swift`):
```graphql
query repoLookup($owner: String!, $name: String!) {
    user(username: $owner) {
        repository(name: $name) { ... }
    }
}
```
The same `user(username:)` root field supports `repositories` and `trackers`
paginated collections on git.sr.ht and todo.sr.ht respectively.

---

## New File: `Hutch/Views/Lookup/UserProfileViewModel.swift`

Create an `@Observable @MainActor` view model following the same pattern as
`RepositoryListViewModel` and `TrackerListViewModel`.

```swift
@Observable
@MainActor
final class UserProfileViewModel {
    private(set) var repositories: [RepositorySummary] = []
    private(set) var trackers: [TrackerSummary] = []
    private(set) var isLoadingRepositories = false
    private(set) var isLoadingTrackers = false
    var repositoriesError: String?
    var trackersError: String?

    private let client: SRHTClient
    let ownerUsername: String  // without leading ~

    init(ownerUsername: String, client: SRHTClient) { ... }

    func loadRepositories() async { ... }
    func loadTrackers() async { ... }
}
```

**GraphQL queries:**

Repositories (execute against `.git` service):
```graphql
query userRepositories($owner: String!) {
    user(username: $owner) {
        repositories {
            results {
                id rid name description visibility updated
                owner { canonicalName }
                HEAD { name target }
            }
            cursor
        }
    }
}
```

Trackers (execute against `.todo` service):
```graphql
query userTrackers($owner: String!) {
    user(username: $owner) {
        trackers {
            results {
                id rid name description visibility updated
                owner { canonicalName }
            }
            cursor
        }
    }
}
```

Decode using private response structs identical to those in
`RepositoryListViewModel` and `TrackerListViewModel`. Map results to
`RepositorySummary` and `TrackerSummary` exactly as those view models do.

---

## Modified File: `Hutch/Views/Lookup/UserProfileView.swift`

### View model instantiation

Add `@State private var profileViewModel: UserProfileViewModel?` and initialise
it in `.task` using `user.canonicalName` with the leading `~` stripped:

```swift
.task {
    let owner = user.canonicalName.hasPrefix("~")
        ? String(user.canonicalName.dropFirst())
        : user.canonicalName
    let vm = UserProfileViewModel(ownerUsername: owner, client: appState.client)
    profileViewModel = vm
    async let repos: () = vm.loadRepositories()
    async let trackers: () = vm.loadTrackers()
    _ = await (repos, trackers)
}
```

Restore `@Environment(AppState.self) private var appState` (it was removed in a
recent commit but is needed for `client` access).

### Repositories section

Add after the existing metadata sections:

```swift
Section {
    if viewModel.isLoadingRepositories && viewModel.repositories.isEmpty {
        ProgressView()
    } else if viewModel.repositories.isEmpty {
        Text("No public repositories.")
            .foregroundStyle(.secondary)
    } else {
        ForEach(viewModel.repositories.prefix(4)) { repo in
            NavigationLink {
                RepositoryDetailView(repository: repo)
            } label: {
                RepositoryRowView(repository: repo, buildStatus: .none)
            }
        }
        if viewModel.repositories.count > 4 {
            NavigationLink("See All") {
                UserRepositoriesView(viewModel: viewModel)
            }
        }
    }
} header: {
    Text("Repositories")
}
```

### Trackers section

Immediately after the Repositories section:

```swift
Section {
    if viewModel.isLoadingTrackers && viewModel.trackers.isEmpty {
        ProgressView()
    } else if viewModel.trackers.isEmpty {
        Text("No public trackers.")
            .foregroundStyle(.secondary)
    } else {
        ForEach(viewModel.trackers.prefix(4)) { tracker in
            NavigationLink {
                TicketListView(tracker: tracker)
            } label: {
                TrackerRowView(tracker: tracker)
            }
        }
        if viewModel.trackers.count > 4 {
            NavigationLink("See All") {
                UserTrackersView(viewModel: viewModel)
            }
        }
    }
} header: {
    Text("Trackers")
}
```

`TrackerRowView` — use the same VStack layout as the private `TrackerRowView`
in `TrackerListView.swift`. Define it as a private struct in
`UserProfileView.swift` rather than duplicating from `TrackerListView`.

---

## New File: `Hutch/Views/Lookup/UserRepositoriesView.swift`

A simple full-list view for "See All" repositories:

```swift
struct UserRepositoriesView: View {
    let viewModel: UserProfileViewModel

    var body: some View {
        List {
            ForEach(viewModel.repositories) { repo in
                NavigationLink {
                    RepositoryDetailView(repository: repo)
                } label: {
                    RepositoryRowView(repository: repo, buildStatus: .none)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Repositories")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoadingRepositories && viewModel.repositories.isEmpty {
                SRHTLoadingStateView(message: "Loading repositories…")
            }
        }
        .refreshable {
            await viewModel.loadRepositories()
        }
    }
}
```

## New File: `Hutch/Views/Lookup/UserTrackersView.swift`

Same pattern as `UserRepositoriesView` but for trackers, navigating to
`TicketListView(tracker:)`.

---

## Navigation context

`UserProfileView` is always presented inside a `NavigationStack` via the sheet
in `LookupView`. `NavigationLink` destinations push correctly within that stack.
No changes to `LookupView` or `MoreRoute` are needed.

---

## Verification

1. Look up a user with public repositories and trackers. Confirm both sections
   appear below the profile metadata.
2. Tap a repository row — confirm `RepositoryDetailView` pushes correctly.
3. Tap a tracker row — confirm `TicketListView` pushes correctly.
4. For users with more than 4 items, confirm "See All" pushes the full list.
5. Look up a user with no public resources — confirm the empty-state text
   renders in each section rather than crashing.
6. Build with no warnings.
