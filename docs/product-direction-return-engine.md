# LinkHive — Product Direction: The Return Engine

**Date:** 2026-09-23
**Author:** Kunj Shingala (office-hours session)
**Status:** Design — approved direction, not yet built
**Mode:** Personal-tool-first (you are user #1)

---

## The one-line problem

You built LinkHive to solve your own problem (scattered "dead links"), and you
still don't use it. You keep saving to LinkedIn saves, Instagram saves, and
WhatsApp-to-self. It's a project, not a product — because it hasn't changed the
behavior of the one person who has the problem most: you.

## Diagnosis (what's actually broken)

Two doors, both failing:

- **Capture (main):** In the moment, your thumb goes to the *native* save button
  inside whatever app you're in. It's one tap, already there. LinkHive asks for a
  share-sheet + a second app. That's more work every time. **You cannot win the
  capture race against native saves. Stop trying to.**
- **Return (also broken):** Even links that do land somewhere never come back.
  LinkedIn saves, Instagram saves, and WhatsApp-to-self are all **write-only
  graveyards.** None of them ever resurface anything. That's why you have three
  piles of dead links and use zero of them.

## The reframe (the whole strategy)

> **LinkHive's job is not to be a better bookmark. It's to be the thing that
> resurrects what you saved. Capture is a commodity. Return is the moat.**

Because you can't intercept Instagram's or LinkedIn's native bookmark button,
the *only* capture path LinkHive can own is the share sheet. So the single
behavior we ask of you is one consistent rule:

> **Whenever you'd save anything, anywhere → Share → LinkHive. One gesture,
> everywhere. It replaces all three graveyards.**

That rule costs exactly one extra tap versus a native save. **That tap is only
rational if the links come back.** So return must be genuinely good — it is the
payment for the capture friction, not a feature.

## Premises (agreed this session)

- **P1 (agreed):** The capture war against Instagram/LinkedIn *native* saves is
  unwinnable — concede it for now.
- **P2 (agreed, with nuance):** WhatsApp-to-self is the most beatable competitor,
  BUT Instagram/LinkedIn saves are also a real pile for you. So the wedge can't be
  WhatsApp-only; it's "one Share→LinkHive gesture for everything share-reachable."
- **P3 (constraint, accepted):** Some Instagram/LinkedIn share-links are
  login-walled. Design assuming "at least the raw link comes back," rich preview
  is best-effort (existing `LinkMetadataService`).

## Decision

**Approach A + C, weighted toward A.**

- **A — Daily Resurface (primary):** Save instantly with zero required fields.
  Once a day, LinkHive pulls you back with ONE card: "N links waiting — here's one
  to look at now." Read / snooze / archive. The daily pull-back IS the habit hook.
- **C — "When should this come back?" (secondary, optional):** At save time, an
  optional one-tap "tonight / weekend / someday." No choice = default into the
  daily resurface pool. Names the true cause of dead links: they have no *when*.

Rejected for v1: **B (Inbox-Zero triage)** — more powerful, but too much UX to
build before you feel the payoff, and triage rituals get abandoned. It's the
mature form to grow into, not to start with.

## v1 scope — the wedge

**Capture**
- Share → LinkHive saves **instantly**. No forced category, no forced priority,
  no forced title. As fast as texting yourself. (Categorize later or never.)
- Optional single row after save: "When should this come back?" → tonight /
  weekend / someday / (skip). Skipping is one tap and totally fine.

**Return (the moat)**
- One daily local notification: "N links waiting. Tap to see one."
- A **single-card focus view** ("Today"): shows one link at a time, big preview.
  Actions: **Open** (mark seen) / **Snooze** (back into pool) / **Archive** (done).
- Anything with a "when" surfaces at that time; everything else flows through the
  daily pool via light spaced resurfacing (don't show the same link every day).

**Explicitly NOT in v1 (conceded for now)**
- Intercepting Instagram/LinkedIn native bookmark saves (impossible).
- Rich previews for login-walled content (best-effort only).
- Inbox-zero triage, streaks, multi-user/cloud-sharing features.
- Any "make it a product for others" work. Win yourself first.

## Capture design decision (refined 2026-09-23)

**Flip the default to instant save. Details become opt-in.**

Current state (for reference): every save — even from the share sheet — forces
the full AddLink form and a deliberate Save tap, and blocks on a metadata spinner.
That is the friction that loses to native bookmarks.

New rule:
- Sharing a URL to LinkHive (or pasting in-app) **saves instantly, zero required
  input.** No form by default.
- The detail form (title, description, priority, categories) is **opt-in**, reached
  by an "Add details" action on the save confirmation. Not a global setting — every
  save is instant, details are always one tap away.
- **Metadata (title, image) fetches in the background AFTER the save.** The bare URL
  persists immediately; the card enriches a moment later. Nothing blocks the save.

**Decided: phased — Path 1 now, Path 2 later.**
- **Phase 1 — Quick-confirm (pure Flutter, ships on current stack) [BUILD FIRST]:**
  Share → LinkHive → app opens, writes to Hive instantly → shows a small "Saved ✓"
  bar with "Add details" + "Undo" → auto-dismisses and returns. Back in ~1s, no
  form. Kills ~90% of the friction. Reuses `ReceiveSharedIntent`,
  `LinkRepository.addLink`. This is also the precondition for a fair habit test —
  manually pasting links is not a real test of the loop.
- **Phase 2 — True background save (native work) [LATER]:** Share → LinkHive →
  saved WITHOUT the full app visibly opening (toast only); you never leave
  Instagram/browser. Closest to a real native bookmark. Needs native
  share-extension/intent handling (Android intent handler + the existing iOS
  ShareExtension) to write without launching the Flutter UI. Do this only once the
  ~1s flash from Phase 1 proves annoying in daily use.

### Phase 1 build — IMPLEMENTED 2026-09-23
Instant-save-on-share is live. Files touched:
- `lib/core/services/receive_shared_intent.dart` — shares now save instantly and
  enrich metadata in the background instead of opening the form.
- `lib/sharedWidgets/saved_link_snackbar.dart` (new) — the "Saved to LinkHive"
  confirmation with **Add details** / **Undo**.
- `lib/features/links/repository/link_repository.dart` — added `getLinkById`.
- `lib/core/utils/locator.dart` — inject repository + metadata service.
- `lib/l10n/app_{en,hi,gu,ar}.arb` — `sharedSaveConfirm`, `sharedAddDetails`,
  `sharedUndo`.
Verified: `fvm flutter analyze` clean, `fvm flutter test` 108 passed.

Original build sketch (for reference):
- `ReceiveSharedIntent._navigateToAddLink`: instead of always pushing the full
  AddLink form, call `LinkRepository.addLink` immediately with the bare URL (fresh
  UUID, `createdAt` now, empty title/desc/categories, priority Normal), then show a
  lightweight confirmation (snackbar or small bottom sheet) with **Add details**
  (pushes the existing AddLink form in edit mode on the just-saved link) and
  **Undo** (deletes it).
- Metadata: after the instant save, kick off `LinkMetadataService.fetchMetadata` in
  the background and update the saved link's title/image when it returns. The card
  enriches without blocking the save. (New: a repo method to enrich by id, or reuse
  `updateLink`.)
- In-app manual **Add**: can keep opening the form (deliberate action), or add a
  quick paste-and-save; not required for Phase 1.
- Requires no `LinkModel` schema change for Phase 1 (the resurface fields for
  A/C return mechanic come in a later step).

## Quick-links Inbox — IMPLEMENTED 2026-09-24

Instant-saved links are now a distinct class ("quick links") managed separately
from the normal collection. A link is organized (promoted out of the Inbox) only
when the user acts on it by adding details.

- **Data:** `LinkModel.isQuickSaved` (Hive field 11, Firestore `isQuickSaved`).
  `true` on instant share-save; flipped `false` when saved through the edit form.
- **Separation:** `queryLinks`, `getUpNextLinks`, and `unreadCount` exclude quick
  links; `queryQuickLinks()` / `quickCount` serve the Inbox. So a link never shows
  in both Home and Inbox.
- **Inbox screen** (`lib/features/inbox/`): dedicated screen + `InboxBloc`
  (watches the box, auto-refreshes). Each row = the standard card + "Add details"
  (→ edit form, promotes it) and delete (confirmed).
- **Entry point:** Home app-bar Inbox button with a live count badge
  (`quickCount` threaded through `LinksLoaded` like `unreadCount`).
- **Route:** `MyRouteName.inbox` → `/inbox`.
- **l10n:** `inboxTitle`, `inboxEmptyTitle`, `inboxEmptySubtitle` (en/hi/gu/ar).
Verified: `fvm flutter analyze` clean, `fvm flutter test` 108 passed.

### Bug fixed 2026-09-24: crash on launch for pre-existing links
Adding `isQuickSaved` as a plain `@HiveField(11)` broke every link saved before
this change: the generated adapter did `fields[11] as bool`, and a missing field
reads back as `null`, so `HiveHelper.init()` threw `type 'Null' is not a subtype
of type 'bool'` on app launch — before any UI rendered. Fixed by annotating the
field `@HiveField(11, defaultValue: false)` and regenerating; the adapter now
does `fields[11] == null ? false : fields[11] as bool`, so old records default to
"managed" (matching the field's documented intent) instead of crashing. No data
lost, no migration needed — re-verified with `fvm flutter analyze` (clean) and
`fvm flutter test` (108 passed).

### Bug fixed 2026-09-24: "Add details" showed a blank form, no auto-fetch
Reported by the user: kill the app, share a link, tap "Add details" — the title
was blank and metadata never auto-fetched; had to tap the manual Fetch button.

Root cause: `AddLinkBloc`'s **edit mode** (used by "Add details") never
auto-fetches metadata — only **add mode** does. This was harmless before Phase 1,
because every link reaching edit mode had already been through a fetch. Quick
links break that assumption: if you open "Add details" before the background
enrichment finishes (slow network, cold start, or a login-walled Insta/LinkedIn
URL that never gets rich metadata), the form has nothing and no trigger to fetch.
A second, smaller bug rode along: the confirmation bar's "Add details" passed the
link object captured at save time (blank), not the current Hive state, so even a
*successful* background enrichment could still show blank until re-fetched.

Fixed:
- `add_link_bloc.dart` — edit mode now auto-fetches metadata when the existing
  link's title is empty (the signal that it was never enriched, or enrichment
  failed) — mirrors add mode's existing auto-fetch.
- `receive_shared_intent.dart` — "Add details" now re-reads the link from the
  repository right before navigating, instead of reusing the stale in-memory copy.
Verified: `fvm flutter analyze` clean, `fvm flutter test` 108 passed.

### Bug fixed 2026-09-24: HTML entities not decoded in extracted metadata
Investigated: user asked whether an X/Twitter link (with no metadata image)
shows an SVG placeholder icon at the Add/Edit screen.

Verified by fetching the actual URL with the app's real User-Agent header: X
*does* return a valid `og:image` — no missing-image/SVG-fallback case at all.
But `LinkMetadataService._extractMeta` captured the attribute value with a raw
regex and never decoded HTML entities, so a URL like
`...?format=webp&amp;name=large` was stored literally — `amp;` and all — an
invalid query string that fails to load from Twitter's CDN. The same bug also
corrupts titles: `&quot;` inside a title showed up as literal text instead of a
quote mark. What actually renders isn't an SVG icon — it's `CachedNetworkImage`'s
broken-image fallback, which likely reads as "some generic icon" at a glance.

Fixed: `link_metadata_service.dart` now decodes `&amp; &lt; &gt; &quot; &#39;
&apos;` plus numeric (`&#39;`) and hex (`&#x27;`) entities on every extracted
title, meta-content, and icon-href value.
Verified: `fvm flutter analyze` clean, `fvm flutter test` 108 passed.

## The only success metric that matters

Not downloads. Not features. **Do YOU, personally, keep using it for 2 weeks?**

Concretely: over 14 days — you save ≥ ~2 links/day via Share→LinkHive, and you
open the daily resurface on ≥ 10 of 14 days, and at least a few resurfaced links
actually get read/watched. If that holds, LinkHive became a product (of one).
If it doesn't, the return loop isn't compelling enough — fix that, not features.

## Build notes (for later — do NOT build yet)

- Reuses: `linksBox`, `ReceiveSharedIntent`, `LinkCard`, `HomeBloc`/`LinkBloc`,
  existing swipe actions, `LinkMetadataService`.
- New: `flutter_local_notifications` (daily + scheduled), a "Today/focus" queue
  view + its BLoC, a `seenAt` / `resurfaceAt` field on `LinkModel`
  (Hive field add → run build_runner), repurpose High/Normal/Low priority into
  time-buckets for C, spaced-resurface ordering logic.
- Follows repo conventions: BLoC sealed classes, NeoBrutalist widgets, `context.l10n`
  strings, `MyRouteName` routing, get_it DI. (See CLAUDE.md.)

## Risks / open questions

1. Will one daily notification be enough of a pull, or ignored? (The assignment
   below tests this before any code.)
2. Login-walled Insta/LinkedIn links: is a bare URL with no preview still useful
   enough to return to? Test with your own real saves.
3. Does the optional "when" add save-time friction that hurts capture? Keep it a
   single tap that's always skippable.

## What I noticed (founder signals)

- **Named the real problem honestly** — "it's a project not a product" is the
  hardest and most useful thing a builder can admit.
- **Solves your own pain** — you built for yourself; that instinct is right, the
  execution just hasn't earned the switch yet.
- **Pushed back with real information** twice (WhatsApp isn't the whole story;
  Insta/LinkedIn saves are a real pile) — that's conviction from lived behavior,
  not compliance. It made the design better.

## The Assignment (do this BEFORE writing any code)

**Manually be the app for 3 days.** No building. This tests whether the loop
even works on you, which is cheaper to learn now than after you build notifications.

1. For the next 3 days, every time you'd save to Insta/LinkedIn/WhatsApp, **also
   paste that link into LinkHive** (manual is fine — you're simulating the one
   gesture).
2. Each morning, open LinkHive and **actually look at one saved link.** Read or
   watch it. Then archive it.
3. Keep a 2-line note each day: *How many did I save? Did I open the morning one?
   Did the resurfaced link still make sense with no preview?*

After 3 days you'll know the truth: does a daily pull-back actually pull *you*?
If yes → build A+C with confidence. If no → the return mechanic needs rethinking
before a single widget gets written. Report back with your 3-day notes.
