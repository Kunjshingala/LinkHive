import 'dart:async';

/// How long one cloud call may take before sync gives up on it.
const Duration cloudCallTimeout = Duration(seconds: 30);

/// Runs [call] and throws a [TimeoutException] if it takes longer than
/// [timeout].
///
/// Offline, a Firestore call can stay pending for as long as the phone has no
/// connection. Without a limit, the sync run that awaits it never ends: the
/// status says "syncing" forever and later requests join that run. A timed-out
/// call is handled like any failed call: the queued write is marked failed and
/// retried with backoff, and the link stays unsynced.
///
/// The request itself is not cancelled. Firestore may still deliver a write
/// that timed out here, which is safe because every write targets a fixed
/// document id and can be repeated.
///
/// [name] says which call it was, for the log.
Future<T> withCallTimeout<T>(
  String name,
  Future<T> Function() call, {
  Duration timeout = cloudCallTimeout,
}) {
  return call().timeout(
    timeout,
    onTimeout: () => throw TimeoutException(
      '$name did not finish within ${timeout.inSeconds}s',
      timeout,
    ),
  );
}
