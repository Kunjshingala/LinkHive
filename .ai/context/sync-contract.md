# Sync contract: accounts, sign-in and sign-out

What the sync layer guarantees and who is responsible for it. Written for issues
#7 (cloud links missing after login) and #8 (local sync state not tied to an
account). Read this before changing `LinkRepository`, `SyncEngine`,
`SyncService` or the sign-out flow.

## The one rule

A device holds the data of **one account at a time** (or of nobody: a guest).
What the user sees always belongs to the signed-in account, plus the guest links
that merged into it on first sign-in.

## Terms

| Term | Meaning |
|---|---|
| Owner | The uid recorded in the settings box (`HiveConstants.ownerUidKey`). Absent for a guest or a legacy install. |
| Cursor | `lastPulledAt` in the settings box. The next pull only asks for changes since this time (minus a 60 s overlap). |
| Outbox | The sync operations box: pending, processing and failed writes waiting for the cloud. |
| Sync state | Links, base links, categories, outbox, tombstones, conflicts and the cursor. Theme and locale are device preferences, not sync state. |
| Wipe | Clearing all sync state. Every wipe goes through `AccountSessionService`. |
| Generation | A counter in `LinkRepository` that every wipe increments. A sync run stops writing locally when it changed. |

## Invariants

1. **One owner.** Sync state on the device belongs to the recorded owner. No push or pull runs for a uid that is not the owner.
2. **Guests merge in.** With no recorded owner, the first account to sync adopts the guest data (its cursor is reset once so the first pull is full).
3. **Foreign data is wiped.** If the recorded owner differs from the signed-in uid, all sync state is wiped and the new uid becomes the owner. This covers a failed sign-out wipe and a restored backup.
4. **Sign-out wipes everything.** Every sign-out clears all sync state. There is no option to keep it.
5. **No late writes.** A sync run that was in flight during a wipe must not write links, operations, categories or the cursor afterwards.
6. **A crash cannot leave a half wipe.** A marker is stored before the wipe and cleared after sign-out. If it is found at app start, the wipe runs again before the first sync.
7. **The user is told the truth.** The sign-out sheet and the status tile show the live state. Offline with pending work is "waiting for internet", never "syncing" and never "failed".
8. **A failed call never counts as synced.** A timed-out or failed Firestore call leaves the link `isSynced = false` and the operation `failed` with backoff.
9. **Migration recovery keeps its promise.** If the link boxes are deleted because they cannot be opened, the cursor is deleted too, so the next pull is a full fetch.

## Who owns what

| Piece | Responsibility |
|---|---|
| `AccountSessionService` | Sequences sign-out and every other wipe, owns wipe-pending recovery at start, counts unsynced work for the sheet. |
| `SyncControl` (implemented by `SyncEngine`) | Serializes runs, refuses new runs while a wipe is in progress, derives the shown status from run state, connectivity and pending count. |
| `LocalDataStore` (implemented by `LinkRepository`) | Local data, the outbox, `claimOrResetFor(uid)`, the generation guard, `clearAll()`, `unsyncedSummary()`. |
| `FirebaseFirestoreService` | Talks to Firestore. Every call has a 30 s timeout. |
| `SyncService` | Connectivity, the 5-minute timer and app lifecycle. Tells the engine when the connection changes. |

## Sequences

### Every sync run

```
 syncPendingLinks / pullFromCloud
   uid = signed-in user, none -> return
   claimOrResetFor(uid)
     owner == uid   -> continue
     owner == null  -> reset cursor once, keep data, owner = uid
     owner != uid   -> wipe all sync state, owner = uid
   capture generation, then push / pull
   before any local write after an await: generation changed -> stop
```

All pull entry points end here: cold start, the auth listener, app resume,
pull-to-refresh and the Account screen.

### Sign-out

```
 tap Sign out -> sheet shows the live state (syncing / waiting for internet, N pending / all synced)
   online -> one sync is requested when the sheet opens
   Sign out, or Sign out anyway:
     recount: grew since the sheet opened -> abort, show the sheet again
     refuse new sync runs
     marker on -> wipe (generation + 1) -> AuthService.signOut -> marker off
   login screen shows "Signed out. This phone's copy was removed; your links are safe in your account."
```

"Delete local data" uses the same wipe path and waits for any running sync first.

### Status shown to the user

```
 offline and pending > 0 -> Waiting for internet, N pending
 online and a run active -> Syncing
 online and an error     -> Could not sync, will retry
 pending == 0            -> All synced
 precedence: conflict, failed (online), waiting, syncing, idle
```

## Edge cases

| Case | Behavior |
|---|---|
| Sign out offline with unsynced work | Sheet says so; "Stay signed in" or "Sign out anyway". Anyway wipes at once; the generation guard drops any late write. |
| Sign out while a sync is running | The user can wait or sign out anyway. Never auto-signs-out. |
| A link is saved while the sheet is open | The count updates live; if it grew after confirm, the wipe aborts and the sheet reappears. |
| App killed mid sign-out | Marker found at start: the wipe runs again before the first sync. |
| Wipe fails | Still signed in, marker stays, retry is safe. |
| Sign-out call fails after the wipe | Still signed in with an empty phone; the next pull refills it. |
| Update on a phone that already holds a stale cursor and no owner | The first sync resets the cursor once (full pull). |
| Google or Firebase sign-out error | Logged; sign-out continues. |

## Not in this contract

Extracting push, pull and merge out of `LinkRepository` (planned, tracked in
`TODOS.md`). Per-account storage. Multi-account switching without signing out.
