# Fix: Conflicting `[Reference]` vs `[ReferenceDetail]` in RepositorySettingsView

## Background

`RepositoryDetailViewModel.branches` was recently changed from `[Reference]` to
`[ReferenceDetail]` to support displaying commit dates in the Refs tab.
`ReferenceDetail` has the same `name: String` and `target: String?` fields as
`Reference`, plus an additional `date: Date?`.

`RepositorySettingsView` and `RepositorySettingsViewModel` still declare their
`branches` parameter as `[Reference]`, causing this compiler error:

```
RepositoryDetailView.swift:56:51
Conflicting arguments to generic parameter 'T' ('[ReferenceDetail]' vs. '[Reference]')
```

The settings view model only uses `branches` for the HEAD branch picker
(`selectedHeadReferenceForSave()` accesses `$0.name`). No mapping back to
`Reference` is needed — just update the type throughout the settings layer.

---

## Changes Required

### 1. `Hutch/Views/Repositories/RepositorySettingsViewModel.swift`

**Change the stored property type:**

Find:
```swift
var branches: [Reference]
```

Replace with:
```swift
var branches: [ReferenceDetail]
```

**Change the `init` parameter type:**

Find:
```swift
init(
    repository: RepositorySummary,
    branches: [Reference],
    client: SRHTClient
) {
```

Replace with:
```swift
init(
    repository: RepositorySummary,
    branches: [ReferenceDetail],
    client: SRHTClient
) {
```

### 2. `Hutch/Views/Repositories/RepositorySettingsView.swift`

**Change the stored property type:**

Find:
```swift
let branches: [Reference]
```

Replace with:
```swift
let branches: [ReferenceDetail]
```

---

## No Other Changes

- Do not modify `Reference` or `ReferenceDetail` in `Git.swift`.
- Do not modify `RepositoryDetailView.swift` — the call site is already correct.
- Do not modify `ReferencesListView.swift` or `RepositoryDetailViewModel.swift`.
- `selectedHeadReferenceForSave()` in the settings view model accesses only
  `$0.name` on each branch, which exists on `ReferenceDetail` — no logic
  changes are needed.

## Verification

Build the project. The compiler error at `RepositoryDetailView.swift:56` should
be gone. Confirm the repository settings sheet still opens and the HEAD branch
picker populates correctly.
