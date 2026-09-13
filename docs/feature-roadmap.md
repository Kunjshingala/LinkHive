# LinkHive — Feature Roadmap

> **Living document.** This tracks every feature planned for LinkHive.  
> Updated as features are discussed, approved, and built.

last_updated: 2026-07-28

---

## How This Doc Works

- Features move through: `Planned` → `In Progress` → `Done`
- Each feature has a **Why** (the user problem it solves) and **What** (what it does)
- Priority reflects what the user would actually use first

---

## 🔴 P0 — Build First (Would use immediately)

> These make LinkHive worth opening daily.

### 1. Clipboard Smart Detect
- **Status:** `Planned`
- **Why:** Too much friction to save a link — you skip saving most of the time.
- **What:** When the app is opened/resumed and a URL is detected on the clipboard, show a non-intrusive prompt: *"Save this link?"* One tap to save.
- **Notes:** Should not be annoying. Show once per unique URL. Dismiss = don't ask again for that URL. `ReceiveSharedIntent` handles OS share sheets but clipboard detection is completely absent.

---

### 2. Duplicate Detection on Save
- **Status:** `Planned`
- **Why:** You end up saving the same link multiple times without realizing it.
- **What:** When saving a new link, check if the URL already exists in Hive. If duplicate found, show: *"You already saved this on [date]"* with options to **open existing** or **save anyway**.
- **Notes:** Normalize URLs before comparison (strip trailing slash, `www.` prefix). Currently `AddLinkBloc` only checks for empty URL — no duplicate check exists.

---

### 3. Quick Actions on Link Card (Enhancement)
- **Status:** `Planned` (enhancing existing)
- **Why:** Too many taps to do basic things with a saved link.
- **What:** Add to existing `LinkCard`: **Copy URL** to clipboard, **Share URL** via OS share sheet, **Open in browser** via `url_launcher`. Consider swipe gestures for speed.
- **Already built:** 3-dot `NeoPopupMenu` with Edit & Delete (with confirmation bottom sheet).
- **Missing:** Copy URL, Share URL, Open in browser. `url_launcher` not in `pubspec.yaml`.

---

## 🟡 P1 — Build Next (High value, not urgent)

### 4. Pin Important Links
- **Status:** `Planned`
- **Why:** Your most-used links get buried under new saves.
- **What:** Toggle pin on any link. Pinned links always appear at the top of the list, regardless of sort order. Visual pin indicator on the card.
- **Notes:** Add `isPinned` boolean field to `LinkModel`. No pin logic exists currently.

---

### 5. Auto-Group / Filter by Source Domain (Enhancement)
- **Status:** `Planned` (enhancing existing)
- **Why:** Manual categorization is tedious. Domain grouping is free context.
- **What:** Add domain-based filter chips (like the existing category/priority filters) on Home Screen. Allow filtering by source: *"Show only YouTube links"*, *"Show only GitHub links"*.
- **Already built:** `LinkCard` extracts and displays host domain via `_extractHost(url)`.
- **Missing:** Domain filter row on Home Screen, domain counting, section headers.

---

### 6. Broken Link Checker
- **Status:** `Planned`
- **Why:** Saved links go stale — pages get deleted, URLs change.
- **What:** Periodically check saved links (HTTP HEAD request). Mark broken links (404/5xx) with a visual indicator. Option to bulk-delete broken links.
- **Notes:** Run in background. Respect rate limits. Only check links not checked in the last 7 days. No health checking exists currently.

---

## 🟢 P2 — Build Later (Nice to have)

### 7. Remind Me Later
- **Status:** `Planned`
- **Why:** "Read later" never happens without a nudge.
- **What:** When saving or viewing a link, option to set a reminder: *"Later today"*, *"Tomorrow"*, *"In 3 days"*, *"Custom"*. Sends a local notification at the set time with the link title.
- **Notes:** Requires `flutter_local_notifications` package. Not implemented at all.

---

### 8. Daily Digest Notification
- **Status:** `Planned`
- **Why:** Links pile up and are never revisited.
- **What:** Optional daily notification (configurable time): *"You saved 2 links yesterday. Here's one from last week you haven't opened."* Tapping opens the app to that link.
- **Notes:** Track `lastOpenedAt` per link. Requires notification infrastructure (same as Remind Me Later).

---

### 9. Home Screen Widget
- **Status:** `Planned`
- **Why:** Out of sight = out of mind. The app needs presence without being opened.
- **What:** Android/iOS home screen widget showing 3–5 most recent links (title + favicon). Tap any = opens in browser.
- **Notes:** Android: `home_widget` package. Start with Android.

---

### 10. Import & Export
- **Status:** `Planned`
- **Why:** Links are scattered across browsers, Keep, WhatsApp. Need to consolidate.
- **What:**
  - **Import:** Chrome bookmarks (HTML file), plain text (one URL per line).
  - **Export:** Share a list of links as plain text, or export all data as JSON backup.
- **Notes:** `AccountScreen` has sync/clear but no file import/export.

---

## Backlog — Ideas for Later

> Not prioritized yet. Added as they come up during discussions.

| # | Feature Idea | One-Line Description |
|---|---|---|
| B.1 | Link collections / shareable lists | Curate and share a themed list of links with others |
| B.2 | Archive instead of delete | Soft-delete — move to archive, recover later |
| B.3 | Dark/Light auto-switch | Follow system theme automatically |

---

## ✅ Already Built (Confirmed by Code Audit)

> These features are fully or substantially implemented. No new work needed.

| Feature | Implementation Details |
|---|---|
| **Auto Metadata Fetch** | `LinkMetadataService` extracts OG/Twitter/HTML title+image+description. `AddLinkBloc` auto-fetches on prefilled URLs. Manual "magic wand" button on `AddLinkScreen`. |
| **Instant Full-Text Search** | `HomeScreen` search bar → `LinkSearchChanged` → `LinkRepository.queryLinks` — case-insensitive search across title, description, URL in Hive. |
| **Quick Note at Save Time** | `LinkModel.description` field. `AddLinkScreen` has 3-line multiline text input for notes. Saved to Hive + synced to Firestore. |
| **Categories (multi-select)** | `CategoryModel` with Hive + Firestore. 8 built-in categories. Custom create/delete via bottom sheet. Multi-select on `AddLinkScreen`. Filter chips on `HomeScreen`. |
| **Priority System** | `LinkPriority` enum (high/normal/low). Priority selector on `AddLinkScreen`. `PriorityBadge` on `LinkCard`. Priority filter row on `HomeScreen`. |
| **Tags (via Categories)** | Categories already act as multi-tags — one link can belong to multiple categories. No separate tag entity needed unless requirements differ. |
| **Domain Display on Cards** | `LinkCard._extractHost(url)` renders the source domain on each card. |
| **Link Card Edit/Delete** | `NeoPopupMenu` with Edit and Delete actions (with confirmation bottom sheet). |
| **OS Share Intent** | `ReceiveSharedIntent` captures links shared from other apps (foreground stream + cold start). |
| **Cloud Sync** | `SyncService` auto-syncs pending links when internet is restored. `SyncMergeHelper` does 3-way merge. |
| **Auth (Email + Google)** | Firebase Auth with email/password and Google Sign-In. |
| **Routing & DI** | `go_router` with named routes. `get_it` with lazy singletons via `locator.dart`. |

---

## Decision Log

> Records key decisions made during feature discussions.

| Date | Decision | Context |
|---|---|---|
| 2026-07-28 | Prioritize utility over flash | User isn't retaining with MVP — features must solve real daily pain points |
| 2026-07-28 | Removed 6 features from roadmap — already built | Code audit confirmed: metadata fetch, search, notes, categories, priorities, tags all exist |
| 2026-07-28 | New P0 = clipboard detect, duplicate detection, quick actions enhancement | Only 3 features in P0 now — all are small, high-impact additions |
| 2026-07-28 | Tags feature dropped | Existing multi-category system already serves as tags |
| 2026-07-28 | Target: make LinkHive the ONE place for links | User currently splits across Chrome, WhatsApp, Keep, LinkedIn, Instagram saves |
