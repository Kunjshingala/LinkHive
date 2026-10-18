import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/services/cloud_sync_service.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

/// A change made while sync is busy with the same link must not be lost (#12).
///
/// Real Hive store, fake cloud. The cloud call or a base write is held open,
/// the user's change happens meanwhile, then the hold is released.
void main() {
  const uid = 'account-a';

  late Directory hiveDirectory;
  late FakeFirebaseFirestoreService cloud;
  late _GatedHiveHelper hiveHelper;
  late LinkRepository repository;
  late CloudSyncService cloudSync;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('linkhive-push-race-test-');
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());
  });

  setUp(() async {
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
    await Future.wait([
      Hive.box(HiveConstants.settingsBox).clear(),
      Hive.box<LinkModel>(HiveConstants.linksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.baseLinksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.conflictLinksBox).clear(),
      Hive.box<CategoryModel>(HiveConstants.categoriesBox).clear(),
      Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).clear(),
      Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).clear(),
      Hive.box<ConflictRecord>(HiveConstants.conflictRecordsBox).clear(),
    ]);

    cloud = FakeFirebaseFirestoreService();
    hiveHelper = _GatedHiveHelper();
    repository = LinkRepository(hiveHelper: hiveHelper);
    cloudSync = CloudSyncService(firebaseService: cloud, store: repository, uidProvider: () => uid);
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  LinkModel link(String id, {String title = 'v1'}) =>
      LinkModel(id: id, url: 'https://example.com/$id', title: title, createdAt: 100);

  /// Holds the first call to [method] open until `release` is called.
  ({Future<void> reached, void Function() release}) holdCall(String method, {Object? thenThrow}) {
    final reached = Completer<void>();
    final gate = Completer<void>();
    cloud.onCall = (called, _) async {
      if (called != method || reached.isCompleted) return;
      reached.complete();
      await gate.future;
      if (thenThrow != null) throw thenThrow;
    };
    return (reached: reached.future, release: gate.complete);
  }

  LinkModel queuedLink(String id) {
    final operation = repository.pendingSyncOperations.singleWhere((operation) => operation.entityId == id);
    return LinkModel.fromFirestore(id, operation.payload);
  }

  group('push', () {
    test('an edit made while its link uploads stays on the phone and queued, '
        'and reaches the cloud on the next push', () async {
      await repository.addLink(link('a-1'));
      final hold = holdCall('saveLink');

      final push = cloudSync.push();
      await hold.reached;
      await repository.updateLink(repository.getLinkById('a-1')!.copyWith(title: 'v2'));
      hold.release();
      await push;

      expect(repository.getLinkById('a-1')!.title, 'v2');
      expect(repository.getLinkById('a-1')!.isSynced, isFalse);
      expect(queuedLink('a-1').title, 'v2');
      expect(cloud.linksOf(uid).single.title, 'v1');

      cloud.onCall = null;
      await cloudSync.push();

      expect(cloud.linksOf(uid).single.title, 'v2');
      expect(repository.pendingSyncOperations, isEmpty);
      expect(repository.getLinkById('a-1')!.title, 'v2');
      expect(repository.getLinkById('a-1')!.isSynced, isTrue);
    });

    test('a link deleted while its create uploads is deleted from the cloud too', () async {
      await repository.addLink(link('a-1'));
      final hold = holdCall('saveLink');

      final push = cloudSync.push();
      await hold.reached;
      await repository.deleteLink('a-1');
      hold.release();
      await push;

      expect(repository.getLinkById('a-1'), isNull);
      cloud.onCall = null;
      await cloudSync.push();

      expect(cloud.linksOf(uid), isEmpty);
      expect(cloud.deletedLinkIdsOf(uid), {'a-1'});
      expect(repository.pendingSyncOperations, isEmpty);
    });

    test('an edit made while a failing upload waits is kept queued', () async {
      await repository.addLink(link('a-1'));
      final hold = holdCall(
        'saveLink',
        thenThrow: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      final push = cloudSync.push();
      await hold.reached;
      await repository.updateLink(repository.getLinkById('a-1')!.copyWith(title: 'v2'));
      hold.release();
      await push;

      expect(repository.getLinkById('a-1')!.title, 'v2');
      expect(queuedLink('a-1').title, 'v2');
      expect(repository.pendingSyncOperations.single.state, SyncOperation.pending);
    });

    test('a link left alone during its upload is marked synced, as before', () async {
      await repository.addLink(link('a-1'));

      await cloudSync.push();

      expect(repository.getLinkById('a-1')!.isSynced, isTrue);
      expect(repository.pendingSyncOperations, isEmpty);
      expect(cloud.linksOf(uid).single.title, 'v1');
    });
  });

  group('pull merge', () {
    test('an edit made while a merge is being written is not replaced by the '
        'merge in the queue', () async {
      // The phone holds a synced copy, then a local title edit that was never
      // queued (so the pull merges instead of skipping it).
      cloud.seedLink(uid, link('m-1').copyWith(description: 'd1'), syncedAt: 1000);
      await cloudSync.pull();
      final synced = repository.getLinkById('m-1')!;
      await Hive.box<LinkModel>(
        HiveConstants.linksBox,
      ).put('m-1', synced.copyWith(title: 'local title', isSynced: false));
      // The cloud changes another field after the last pull.
      cloud.seedLink(uid, synced.copyWith(description: 'd2'), syncedAt: DateTime.now().toUtc().millisecondsSinceEpoch);

      final baseWrite = hiveHelper.holdBasePut('m-1');
      final pull = cloudSync.pull();
      await baseWrite.reached;
      // The merged link is on the phone now; the user edits it.
      final merged = repository.getLinkById('m-1')!;
      expect(merged.description, 'd2');
      await repository.updateLink(merged.copyWith(priority: 'High'));
      baseWrite.release();
      await pull;

      final local = repository.getLinkById('m-1')!;
      expect(local.priority, 'High');
      expect(local.title, 'local title');
      expect(local.description, 'd2');
      expect(queuedLink('m-1').priority, 'High');
    });
  });
}

/// [HiveHelper] whose base-links box can hold one `put` open.
class _GatedHiveHelper extends HiveHelper {
  _GatedBaseBox? _gated;

  ({Future<void> reached, void Function() release}) holdBasePut(String key) {
    final reached = Completer<void>();
    final gate = Completer<void>();
    _gated = _GatedBaseBox(super.baseLinksBox, key, reached, gate.future);
    return (reached: reached.future, release: gate.complete);
  }

  @override
  Box<LinkModel> get baseLinksBox => _gated ?? super.baseLinksBox;
}

/// Forwards to [_inner]; the first `put` of [_key] waits for [_gate].
class _GatedBaseBox implements Box<LinkModel> {
  _GatedBaseBox(this._inner, this._key, this._reached, this._gate);

  final Box<LinkModel> _inner;
  final String _key;
  final Completer<void> _reached;
  final Future<void> _gate;

  @override
  Future<void> put(dynamic key, LinkModel value) async {
    if (key == _key && !_reached.isCompleted) {
      _reached.complete();
      await _gate;
    }
    await _inner.put(key, value);
  }

  @override
  LinkModel? get(dynamic key, {LinkModel? defaultValue}) => _inner.get(key, defaultValue: defaultValue);

  @override
  Future<void> delete(dynamic key) => _inner.delete(key);

  @override
  Future<int> clear() => _inner.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName} is not gated');
}
