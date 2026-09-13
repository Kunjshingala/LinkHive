import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/sync_backoff.dart';

void main() {
  test('uses deterministic exponential delays capped at one hour', () {
    expect(SyncBackoff.delayForAttempt(0), Duration.zero);
    expect(SyncBackoff.delayForAttempt(1), const Duration(seconds: 1));
    expect(SyncBackoff.delayForAttempt(2), const Duration(seconds: 2));
    expect(SyncBackoff.delayForAttempt(3), const Duration(seconds: 4));
    expect(SyncBackoff.delayForAttempt(20), const Duration(hours: 1));
  });
}
