# Domain Context — LinkHive

## Core Concept

LinkHive is a **link management app**. The primary user flow is:
1. User finds a URL in another app (browser, Twitter, Reddit, etc.)
2. User shares it to LinkHive via the OS share sheet
3. LinkHive captures, stores, and organizes the link
4. User browses/manages their saved links in-app

---

## Key Domain Terms

| Term | Meaning |
|---|---|
| **Link** | A URL shared into or manually entered into the app |
| **Hive** | The user's personal collection of saved links |
| **Share intent** | The OS mechanism that delivers a shared link to the app |
| **Auth gate** | The UI boundary that routes users to Home or Login based on auth state |
| **Splash** | Initial load screen — not a branding moment, an auth-check transition |

---

## User Roles

Currently a **single-user, personal app** — no multi-user or collaboration features are planned in the immediate roadmap. Each Firebase Auth user owns their own set of links (Firestore separation by UID).

---

## Business Rules

- **Optional Authentication (Local-First)**: A user is NOT required to be authenticated to store or view links. Links can be stored locally on the device.
- **Sync**: If the user is authenticated, their local links will automatically sync to Firestore (cloud backup).
- **Privacy**: If synced to the cloud, links are private to the authenticated user.
- **Background Intent**: The app must handle share intents even when launched cold (not already running).
- **Graceful Sign-out**: Sign-out should optionally clear local state (based on user choice) and return the user to the auth screen, but the app can still be used locally.

---

## Feature Status

### Done
1. **Local-First Storage** — Hive boxes persist links, categories, and settings immediately offline.
2. **Cloud Sync** — background sync via pending operations queue; pushed to Firestore on connectivity restore or sign-in.
3. **Link display** — paginated list on HomeScreen (20/page); reactive to Hive writes without manual reload.
4. **Link metadata** — OG/Twitter title, description, image auto-extracted on URL entry in AddLink screen (debounced 300ms).
5. **Unified Categories** — built-in suggested categories + user-created custom; multi-select; long-press delete from home filter chips.
6. **Priority** — High / Normal / Low per link; filter chip on home screen; defaults to Normal.
7. **Search** — debounced full-text search across title, description, and URL; combined with category and priority filters.
8. **Share intent** — foreground and cold-start; extracts URL and opens AddLink screen pre-filled.
9. **Edit / Delete** — edit pre-populates AddLink form; delete removes from Hive and queues a remote delete tombstone.
10. **Conflict resolution** — detect and record field-level conflicts; keep-local / keep-cloud / custom merge flows.

### Remaining Gaps
- **Image preview** — OG image URL is fetched and stored but not rendered anywhere in the UI.
- **Sync retry** — failed sync operations stay in the queue and retry on next periodic trigger (5 min) or manual sync; no exponential back-off retry loop.
- **Non-URL share handling** — file and plain-text shares are silently ignored; only `http://` / `https://` shares are accepted.
