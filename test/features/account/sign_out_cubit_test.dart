import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/account_session_service.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/account/sign_out/sign_out_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountSessionService extends Mock implements AccountSessionService {}

void main() {
  late MockAccountSessionService session;
  late StreamController<SyncSnapshot> live;

  const nothingToLose = SyncSnapshot();
  const waiting = SyncSnapshot(status: SyncStatus.waitingForInternet, pendingChanges: 2);

  setUp(() {
    session = MockAccountSessionService();
    live = StreamController<SyncSnapshot>.broadcast();
    when(() => session.syncSnapshot).thenReturn(nothingToLose);
    when(() => session.watchSync()).thenAnswer((_) => live.stream);
    when(() => session.requestSync()).thenAnswer((_) async {});
  });

  tearDown(() => live.close());

  SignOutCubit build() => SignOutCubit(sessionService: session);

  test('starts from what the sync engine shows right now', () async {
    when(() => session.syncSnapshot).thenReturn(waiting);

    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, waiting);
  });

  blocTest<SignOutCubit, SyncSnapshot>(
    'follows the sync engine while the sheet is open',
    build: build,
    act: (_) {
      live
        ..add(waiting)
        ..add(nothingToLose);
    },
    expect: () => [waiting, nothingToLose],
  );

  test('asks for a sync when it opens with unsynced work', () async {
    when(() => session.syncSnapshot).thenReturn(waiting);

    final cubit = build();
    addTearDown(cubit.close);

    verify(() => session.requestSync()).called(1);
  });

  test('does not touch the cloud when there is nothing to sync', () async {
    final cubit = build();
    addTearDown(cubit.close);

    verifyNever(() => session.requestSync());
  });

  test('syncNow asks the session service for one sync', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.syncNow();

    verify(() => session.requestSync()).called(1);
  });

  test('stops listening when the sheet closes', () async {
    final cubit = build();

    await cubit.close();

    expect(live.hasListener, isFalse);
  });
}
