# TODO

---

## TODO List

### Core Functionality

- Implement manual `~owner/repo` lookup flow for opening git.sr.ht or hg.sr.ht
  repositories directly

---

### paste.sr.ht

- **Endpoint:** [https://paste.sr.ht/graphql](https://paste.sr.ht/graphql)
- **Scope:** `PASTES:RO` (browsing), `PASTES:RW` (creation/editing)

**Tasks:**

- Show the authenticated user’s pastes
- Allow viewing individual pastes
- Support creating new pastes

---

### lists.sr.ht

- **Endpoint:** [https://lists.sr.ht/graphql](https://lists.sr.ht/graphql)
- **Scope:** `LISTS:RO`

**Tasks:**

- Show the authenticated user’s mailing lists
- Allow browsing email threads
- Display individual emails as plain text

---

### pages.sr.ht

- **Endpoint:** [https://pages.sr.ht/graphql](https://pages.sr.ht/graphql)

**Tasks:**

- Show the authenticated user’s published sites
- Display site metadata, publishing status, and access control where supported
- For managing Pages sites, not browsing public project discovery

---

### Donation Page / In-App Purchases

- Add a donation/support page once the App Store / StoreKit setup is ready

---

## Out of Scope

- Universal links (requires Sourcehut to host an apple-app-site-association
  file)
- Push notifications for builds and tickets (requires a backend relay server)
- Contribution activity / GitHub-style heatmap (no aggregate endpoint,
  impractical to compute)
- Explore / search (hub.sr.ht) (no public discovery API)
- Pronouns on profile (not in GraphQL schema)
- Revoke personal access tokens (`@internal` in schema, inaccessible)
