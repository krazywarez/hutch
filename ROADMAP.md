# Hutch Roadmap

## Positioning

Hutch is already beyond a minimal v1. The core SourceHut surfaces are present:

- Authentication with PAT flow
- Git repositories
- Mercurial repositories
- Trackers and tickets
- Builds
- Sharing
- Core settings and app metadata

The main risk now is not lack of scope. The main risk is shipping too late with
an increasingly broad surface area and not enough polish.

This roadmap treats the current app as a real 1.0 candidate and shifts the
focus from feature expansion to launch readiness.

## Version 1.0 Goal

Ship a stable SourceHut mobile client with strong support for the most active
day-to-day workflows:

- Browse and manage repositories
- Browse and manage tickets
- Browse and manage builds
- Support both git and hg repositories
- Provide dependable sharing and navigation

Version 1.0 does not need to cover every sr.ht service.

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
  - repository
  - commit
  - file
- Verify sharing links for:
  - build
  - tracker
  - ticket
  - profile
- Review empty/loading/error states across all main tabs
- Remove any leftover temporary debug logging
- Audit device-only issues:
  - Xcode attach quirks
  - on-device auth/cache behavior
  - WebView rendering performance

#### UI/UX polish checklist

- Tighten wording and error messages across create/edit flows
- Confirm summary tabs feel consistent across git and hg
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

### Phase 3: Version 1.2+

Expand only after the v1 core is stable in the wild.

- lists.sr.ht tab
- paste.sr.ht creation/editing polish
- pages.sr.ht management
- broader deep-link/share coverage
- workflow refinements for builds and tickets

## What Counts As “Done Enough” For 1.0

Hutch is ready for 1.0 when:

- The main flows work reliably on real devices
- Errors are understandable
- The app does not feel inconsistent across git/hg/builds/tickets
- The missing services feel like roadmap items, not broken gaps

That means `lists.sr.ht`, `paste.sr.ht`, and `pages.sr.ht` are not blockers for
the first release.

## Non-Blockers For 1.0

These should not delay launch:

- Donation page / IAP
- Broad service parity across all SourceHut products
- Public repo discovery equivalent to `sr.ht/projects`
- Advanced creation workflows beyond what the public APIs cleanly support

## Open Product Questions

These are worth deciding before or shortly after launch:

- Should the app be positioned as “SourceHut client” or “SourceHut for git/hg,
  tickets, and builds” in App Store messaging?
- Should exact repository lookup live in Repositories search, a dedicated sheet,
  or both?
- Should `paste.sr.ht` or `lists.sr.ht` be the first new post-launch tab?
- Is TestFlight feedback needed before calling the first public build 1.0?

## Recommended Next Step

Do not add another major service right away.

Instead:

1. Run a release-focused polish pass
2. Build a strict 1.0 checklist from the current app
3. Ship to TestFlight or release publicly
4. Use `ROADMAP.md` and `TODO.md` separately:
   - `ROADMAP.md` for release strategy
   - `TODO.md` for concrete implementation backlog
