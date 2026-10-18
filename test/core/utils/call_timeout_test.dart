import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/call_timeout.dart';

void main() {
  const shortTimeout = Duration(milliseconds: 20);

  test('returns the value of a call that finishes in time', () async {
    final result = await withCallTimeout('fetchLinks', () async => 42, timeout: shortTimeout);

    expect(result, 42);
  });

  test('fails with a TimeoutException naming the call when it is held open', () async {
    final held = Completer<int>();

    await expectLater(
      withCallTimeout('saveLink', () => held.future, timeout: shortTimeout),
      throwsA(
        isA<TimeoutException>()
            .having((e) => e.message, 'message', contains('saveLink'))
            .having((e) => e.duration, 'duration', shortTimeout),
      ),
    );
  });

  test('passes the call\'s own error through unchanged', () async {
    await expectLater(
      withCallTimeout<int>('deleteLink', () => Future<int>.error(StateError('denied')), timeout: shortTimeout),
      throwsA(isA<StateError>()),
    );
  });

  test('a call that finishes after the timeout does not raise a second error', () async {
    final held = Completer<int>();
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      await expectLater(
        withCallTimeout('saveLink', () => held.future, timeout: shortTimeout),
        throwsA(isA<TimeoutException>()),
      );
      held.complete(1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }, (error, stack) => unhandled.add(error));

    expect(unhandled, isEmpty);
  });

  test('the default limit is 30 seconds', () {
    expect(cloudCallTimeout, const Duration(seconds: 30));
  });
}
