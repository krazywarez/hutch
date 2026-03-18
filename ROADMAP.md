# Hutch Roadmap

## Version 1.0 Goal

Ship a stable SourceHut mobile client with strong support for the most active
day-to-day workflows:

- Browse and manage repositories
- Browse and manage tickets
- Browse and manage builds
- Support both Git and Mercurial repositories
- Provide dependable sharing and navigation

Version 1.0 does not need to cover every SourceHut service.

---

## Release Strategy

### Phase 1: Ship Readiness

Focus on quality, not new surface area.

#### Core release checklist

- Verify authentication flow on simulator and physical device
- Verify reset/sign-out/reset-app-data flow on simulator and physical device
- Verify all destructive actions have confirmation and correct follow-up state
- Verify all create flows succeed end-to-end:
  - Git repository
  - Mercurial repository
  - Tracker
  - Ticket
  - Build submission
- Verify build retry and edit/resubmit flows
- Verify repository sharing links for:
  - Repository
  - Commit
  - File
- Verify sharing links for:
  - Build
  - Tracker
  - Ticket
  - Profile
- Review empty/loading/error states across all main tabs
- Remove any leftover temporary debug logging
- Audit device-only issues:
  - Xcode attach quirks
  - On-device auth/cache behavior
  - WebView rendering performance

#### UI/UX polish checklist

- Tighten wording and error messages across create/edit flows
- Confirm summary tabs feel consistent across Git and Mercurial
- Confirm toolbar actions are visible and non-duplicated
- Confirm README rendering is smooth on large repositories
- Confirm forms behave well on iPhone-sized screens
- Confirm keyboard behavior and dismissal in all creation sheets

#### App Store readiness

- Finalize app icon and screenshots
- Finalize App Store copy
- Finalize privacy details
- Finalize support URL / project URL
- Decide whether TestFlight comes before public launch

---

### Phase 2: Version 1.1

Add one compact new service surface after launch.

#### Recommended priority

1. Exact repository lookup
2. paste.sr.ht
3. lists.sr.ht

#### Why

- Exact repository lookup solves a real gap created by the lack of public
  discovery APIs
- paste.sr.ht is relatively self-contained
- lists.sr.ht is valuable, but broader in UI and data model scope

---

### Phase 3: Version 1.2+

Expand only after the v1 core is stable in the wild.

- lists.sr.ht tab
- paste.sr.ht creation/editing polish
- pages.sr.ht management
- Broader deep-link/share coverage
- Workflow refinements for builds and tickets
