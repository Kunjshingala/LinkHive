# LinkHive Offline-First Sync Engine

Status: Proposed
Date: 2026-09-13

## Implementation Progress

This section is the handoff record for continuing the refactor across sessions.

### Completed

- Phase 1 — durable local foundation: `3bc8506`
  - Added Hive outbox operations and durable tombstones.
  - Made link/category writes local-first with operation coalescing.
  - Added restart and repository persistence tests.
- Phase 2 — serialized push engine: `05cfe14`
  - Added single-flight `SyncEngine` and deterministic exponential backoff.
  - Wired startup, auth-state, connectivity, and manual refresh triggers.
  - Added engine and retry tests.
- Phase 3 — pull reconciliation: `e83546d`
  - Added push-then-pull sign-in/startup behavior.
  - Added remote category tombstones and outbox-aware pull protection.
  - Added persisted `ConflictRecord`s and pull/conflict tests.

### Current phase

- Phase 4 — conflict resolution and observability: `81e8cfe`
  - Added keep-local, keep-cloud, and explicit merged-link resolution APIs.
  - `SyncEngine` now exposes `SyncStatus` events: `idle`, `syncing`, `failed`, and `conflict`.

- Phase 5 infrastructure hardening: `44af8d3`
  - Recover operations left in `processing` on the next sync attempt.
  - Add app-resume and periodic foreground sync triggers.
  - Route Account manual sync through the serialized engine.
- Phase 6 — conflict resolution UI: `5c70b5b`
  - Added a Bloc-backed conflict screen with Keep local and Keep cloud actions.
  - Kept explicit merged-link resolution available through the repository API.

- Phase 7 — user-facing sync status: `6e0f0aa`.
  - Added a Bloc-backed Account status card driven by `SyncEngine.statusStream`.
  - Displays idle, syncing, failed, and conflict states.

### Next work

- Incremental pull cursor/overlap-window strategy and broader two-device/delete-edit tests remain pending.
- Metrics and structured sync failure reporting remain pending.
- The attempted cursor schema spike was rolled back before commit; no partial cursor changes remain.

## Goal

Make local Hive data authoritative for the UI while reliably synchronizing changes with Firestore whenever a user is authenticated and connectivity is available.

The sync engine must be:

- offline-first and usable without authentication;
- idempotent, so retries do not duplicate or corrupt data;
- resilient to app termination and intermittent connectivity;
- deterministic when the same record changes on multiple devices;
- observable, so the UI can show sync state and actionable errors.

## Current Issues

### Critical correctness issues

1. **Offline deletions are not durable.** `LinkRepository.deleteLink()` removes the local link immediately, but does not persist a pending deletion. If the device is offline, a later cloud pull can restore the deleted document.

2. **Offline edits to synced links can be lost.** `updateLink()` writes the edited link locally while retaining its previous `isSynced` value. If that value is `true`, the failed cloud update is never selected by `syncPendingLinks()`.

3. **The sync service does not pull remote changes.** `SyncService` only calls `syncPendingLinks()` after connectivity changes. Changes made on another device are not automatically merged.

4. **Sync state is represented on the domain object instead of the operation.** A boolean `isSynced` cannot represent pending creates, updates, deletes, retries, or permanent failures safely.

5. **Server timestamps are not reconciled locally.** A successful upload marks a link as synced, but the server-generated `syncedAt` value is not read back into Hive.

### Important reliability issues

6. **There is no durable retry/backoff policy.** Failed writes are logged, but there is no attempt count, next retry time, or classification between transient and permanent failures.

7. **Deletes are not modeled as tombstones locally.** Firestore tombstones exist for cloud reconciliation, but local pending deletes do not survive process death.

8. **Category writes have no pending-operation queue.** A locally saved category can fail to upload and has no reliable retry marker.

9. **Sync is not serialized.** Connectivity callbacks, manual Home sync, and other future triggers can overlap and race while mutating the same Hive boxes.

10. **Conflict handling is incomplete from a user perspective.** Three-way merge exists, but conflict records and merge decisions are not exposed through a clear recovery flow.

11. **Authentication transitions are not sync triggers.** Sign-in should pull remote data and upload local pending data. Sign-out should stop cloud work and preserve local-only usage.

    **Required regression scenario:** create an account, save and sync three
    links, sign out using **delete local data only**, then sign in again. The
    three links must be restored from Firestore into the local Hive view. The
    current implementation loses them from the UI because sign-in only calls
    `syncPendingLinks()` and does not call `pullFromCloud()`.

12. **Metadata fetching is not isolated from saving.** Metadata failure should never block saving a valid URL, and the metadata request should be cancellable or safely ignored if the form changes.

13. **Home pagination is local-only and currently materializes the full Hive box.** `LinkRepository.queryLinks()` reads all local links, sorts and filters them, then applies `skip(offset).take(limit)`. Firestore exposes `fetchPaginatedLinks()`, but Home and `LinkBloc` do not use it. This is correct for offline-first reads, but it will become inefficient for very large local collections.

## Target Architecture

```text
UI / BLoC
   |
   v
Local Repository  --->  Hive materialized view (links, categories)
   |                         ^
   v                         |
Sync Queue (outbox) ---> Sync Engine <--- Connectivity/Auth triggers
                              |
                              v
                      Firestore Data Gateway
                              |
                              v
                       Remote change pull
```

The UI reads only from the local materialized view. Repository mutations update the view and append an outbox operation in one local transaction-like sequence. The Sync Engine later processes the outbox and pulls remote changes.

### Pagination boundary

Home scrolling should continue to paginate the local materialized view so the UI never depends on network latency. The Sync Engine should pull remote changes independently and write them into that local view. Scrolling must not directly call Firestore.

For larger datasets, replace the current `values.toList()` approach with a real local query/paging mechanism. Remote Firestore pagination can be used inside the pull phase or for bounded backfill, using a cursor, but it should not become the primary source for the Home list. This preserves offline behavior and prevents duplicate or inconsistent pages while sync is running.

## Record Identity and Matching

The primary identity of a link must be a stable client-generated UUID:

```text
linkId = UUID v4
```

The same ID is used consistently across the system:

```text
Hive key:              linkId
Firestore document:    users/{uid}/links/{linkId}
Outbox entityId:        linkId
Conflict linkId:        linkId
```

The URL must not be used as the primary identity. A URL can change while the user is still editing the same saved record. Instead, use separate values for separate purposes:

| Purpose | Value |
|---|---|
| Match the same record | Stable `linkId` |
| Detect possible duplicate URLs | Normalized URL |
| Identify one retryable sync operation | `operationId` |
| Detect ordering and changes | `updatedAt` or revision |
| Identify the owner | Firebase `uid` |

URL normalization is useful for duplicate detection only. For example:

```text
https://www.example.com/article/
→ https://example.com/article
```

This normalized value can warn the user that a similar link already exists, but it must not replace the stable `linkId`.

## Proposed Local Data Model

### Link record

Keep `LinkModel` focused on user data. Add a stable revision field rather than relying only on `isSynced`:

- `id`
- `url`, `title`, `description`, `image`
- `categories`, `priority`
- `createdAt`, `updatedAt`
- `deletedAt` when using local soft deletion
- `serverUpdatedAt` when known
- `revision` or a comparable monotonic local version

`isSynced` may remain temporarily for UI compatibility, but it should not control synchronization decisions.

### Outbox operation

Create a Hive `SyncOperation` model:

- `operationId`: UUID, idempotency key;
- `entityType`: link or category;
- `entityId`;
- `operationType`: create, update, delete;
- `payload`: serialized snapshot for create/update;
- `createdAt`;
- `attemptCount`;
- `nextAttemptAt`;
- `lastError`;
- `state`: pending, processing, failed, blocked;
- optional `baseServerUpdatedAt` for conflict detection.

Use one operation per entity in the normal case. New changes should coalesce an existing pending operation where safe: create + update becomes create with the newest payload; create + delete can be removed locally without a remote operation; update + delete becomes delete.

### Tombstones

Do not immediately forget a deleted entity. Retain a local tombstone until the delete has been acknowledged by Firestore and the retention window has passed. This prevents an older remote snapshot from recreating the record.

## Sync Algorithm

### Local write

1. Validate and normalize the input.
2. Write the new materialized local state.
3. Append or coalesce an outbox operation.
4. Notify the UI immediately.
5. Request a background sync if authenticated and online.

The local write must succeed even when Firebase is unavailable.

### Push phase

1. Acquire a single-flight sync lock.
2. Read pending operations ordered by creation time.
3. Mark one operation as processing.
4. Send it using a deterministic Firestore document ID and operation ID.
5. On success, acknowledge/remove the operation and update local server metadata.
6. On transient failure, return it to pending with exponential backoff and jitter.
7. On validation/authentication failure, mark it blocked and expose the reason.
8. Continue processing independent operations.

All Firestore writes must be idempotent. Replaying an operation with the same entity ID must produce the same final document, not a duplicate.

### Pull phase

After push, pull remote changes using a per-user sync cursor such as `lastPulledAt` or a server change feed. If a change feed is not introduced initially, use a bounded query ordered by `updatedAt` and maintain a conservative overlap window.

For each remote record:

- ignore it when a matching local outbox operation is newer and still pending;
- apply it directly when there is no local dirty state;
- run a three-way merge when both local and remote changed since the common base;
- create a conflict record when fields cannot be merged safely.

For remote deletions, apply the same rules using tombstones.

### Conflict policy

Use field-level merge for independent fields:

- title, description, image, priority, and categories can be merged when only one side changed;
- URL and identity changes should create an explicit conflict;
- delete versus edit should preserve the edited copy as a conflict rather than silently losing data.

The first release should provide a conflict screen with `Keep local`, `Keep cloud`, and `Merge` actions. Never silently discard a user edit.

### Multiple links and partial changes

Conflicts are evaluated per link and per field, not for the entire synchronization batch.

Example:

```text
Link A: local title change, cloud priority change
        → merge automatically

Link B: local title change, cloud title change
        → create one title conflict

Link C: local description change only
        → upload local version

Link D: cloud category change only
        → accept cloud version
```

One conflict must not block unrelated links. A sync run may therefore finish with a result such as:

```text
4 links processed
3 synchronized automatically
1 conflict requiring attention
```

Use three-way comparison for each link:

```text
Base   = last version shared by local and cloud
Local  = current local version
Cloud  = current remote version
```

If only local changed, keep local and upload it. If only cloud changed, accept cloud. If different fields changed, merge the fields. If the same field changed on both sides, preserve both values in a conflict record.

```text
ConflictRecord
--------------
linkId:            link_123
conflictingFields: [title]
baseVersion:       ...
localVersion:      ...
cloudVersion:      ...
status:            unresolved
```

Title, URL, and delete-versus-edit conflicts should normally require user choice. Independent fields such as description, priority, and categories can be merged automatically when only one side changed them.

After the user chooses `Keep local`, `Keep cloud`, or manually edits the value, save the final result locally, mark the conflict resolved, create a new update operation, upload the result, and store it as the new common base.

## Triggers

The Sync Engine should be triggered by:

- app startup;
- app resume;
- connectivity becoming available;
- successful sign-in or account change;
- a local write;
- manual pull-to-refresh;
- a periodic foreground timer while the app is active.

Triggers should enqueue a request, not start an independent sync. The engine must collapse concurrent requests into one run.

## Authentication and Local-First Behavior

- Anonymous/local mode writes only to Hive and still records outbox operations.
- After sign-in, associate existing local operations with the authenticated user and run push then pull.
- On sign-out, stop the active sync, clear user-specific cloud cursors, and keep local data unless the user explicitly chooses to clear it.
- Never upload one user’s local data under another user’s UID.
- If multiple accounts are supported on one device, partition local data or migrate it explicitly during account selection.

## Firestore Requirements

Each user document should contain:

- `links/{linkId}` with `createdAt`, `updatedAt`, and a server-side revision/timestamp;
- `categories/{categoryId}` with the same update metadata;
- `deletedLinks/{linkId}` tombstones with deletion metadata;
- optional `syncState` containing the client cursor and schema version.

Firestore security rules must restrict every collection to the authenticated user’s UID. Client-provided ownership fields must not be trusted for authorization.

## Implementation Phases

### Phase 1 — Correctness foundation

- Add `SyncOperation` and Hive adapter.
- Add durable outbox and tombstone boxes.
- Change create/update/delete repository methods to write outbox operations.
- Fix update and delete retry behavior.
- Add repository tests for offline create, update, delete, restart, and retry.

### Phase 2 — Sync engine

- Create `SyncEngine` with a single-flight lock.
- Implement push processing, retry/backoff, operation coalescing, and acknowledgement.
- Add auth and connectivity triggers.
- Keep `SyncService` as a compatibility façade or replace it with the engine.

### Phase 3 — Pull and reconciliation

- Add remote change cursor/state.
- Run push-before-pull.
- Integrate three-way merge with dirty-operation checks.
- Preserve tombstones during pull.
- Add conflict persistence and UI actions.

### Phase 4 — Observability and hardening

- Add `SyncStatus` to BLoC state: idle, syncing, offline, failed, conflict.
- Show last successful sync and pending count in Account/Home.
- Add structured logs and metrics for operation latency/failures.
- Test process restart, airplane mode, duplicate callbacks, two-device edits, delete/edit races, and auth changes.

## Acceptance Criteria

- A link saved offline appears immediately and uploads after reconnecting.
- An edited synced link uploads after an offline edit.
- An offline deletion never reappears after a later pull.
- App termination during any operation is safe; the operation resumes on restart.
- Retried operations never create duplicate Firestore documents.
- A second device’s changes appear without requiring a manual full reload.
- After three links are synced, signing out with local-data deletion enabled
  and signing in again restores all three links from the cloud.
- Conflicts are preserved and actionable, never silently discarded.
- Local-only users can use the app without Firebase connectivity.
- Sync runs at most once concurrently per user.
- All repository and engine behavior is covered by deterministic tests.

## Recommended First Implementation Step

Implement Phase 1 before adding more sync features. The current boolean-based approach cannot reliably represent pending updates and deletes; adding more pull or merge logic before a durable outbox would make the existing correctness problems harder to reason about.
