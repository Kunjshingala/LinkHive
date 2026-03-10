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

## Planned Features (not yet built)

1. **Local-First Storage** — persist links locally (Hive/SQLite) immediately.
2. **Cloud Sync** — background sync local data to Firestore when authenticated & connected.
3. **Link display** — list/grid view of saved links on HomeScreen.
4. **Link metadata** — title, description, favicon auto-extracted from the URL via Share Intent or manual entry.
5. **Unified Categories** — flexible organization combining folders and tags into one priority-based system (High, Normal, Low).
6. **Search** — full-text search over saved links.
