import 'package:get_it/get_it.dart';

import '../../features/links/manager/link_manager.dart';
import '../../features/links/repository/link_repository.dart';
import '../services/account_session_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/link_metadata_service.dart';
import '../services/home_widget_service.dart';
import '../services/receive_shared_intent.dart';
import '../services/resurface_notification_service.dart';
import '../services/sync_service.dart';
import '../services/sync_engine.dart';
import 'hive_helper.dart';

final locator = GetIt.instance;

void setupLocator() {
  // ─── Auth & Intent services ─────────────────────────────────────
  locator.registerLazySingleton<AuthService>(() => AuthService());
  // Lazy singleton: the factory runs on first resolve (in MyApp.initState),
  // by which point LinkRepository and LinkMetadataService are registered.
  locator.registerLazySingleton<ReceiveSharedIntent>(
    () => ReceiveSharedIntent(
      manager: locator<LinkManager>(),
      metadataService: locator<LinkMetadataService>(),
    ),
  );
  locator.registerLazySingleton<ResurfaceNotificationService>(
    () => ResurfaceNotificationService(),
  );
  locator.registerLazySingleton<HomeWidgetService>(
    () => HomeWidgetService(manager: locator<LinkManager>()),
  );

  // ─── Firebase / Cloud ───────────────────────────────────────────
  locator.registerLazySingleton<FirebaseFirestoreService>(
    () => FirebaseFirestoreService(),
  );

  // ─── Hive ─────────────────────────────────────────────────────────
  locator.registerLazySingleton<HiveHelper>(() => HiveHelper());

  // ─── Metadata ───────────────────────────────────────────────────
  locator.registerLazySingleton<LinkMetadataService>(
    () => LinkMetadataService(),
  );

  // ─── Repository ─────────────────────────────────────────────────
  locator.registerLazySingleton<LinkRepository>(
    () => LinkRepository(hiveHelper: locator<HiveHelper>()),
  );

  // ─── Cloud sync (push, pull, merge; the only Firestore user) ────
  locator.registerLazySingleton<CloudSyncService>(
    () => CloudSyncService(
      firebaseService: locator<FirebaseFirestoreService>(),
      store: locator<LinkRepository>(),
    ),
  );

  // ─── Link actions ───────────────────────────────────────────────
  // Every "do something to a link" composite (open / archive / snooze) lives
  // here so the behavior is defined once. The repository stays the single
  // source for persistence; this is the single source for actions.
  locator.registerLazySingleton<LinkManager>(
    () => LinkManager(repository: locator<LinkRepository>()),
  );

  locator.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      cloudSync: locator<CloudSyncService>(),
      repository: locator<LinkRepository>(),
    ),
  );

  // ─── Account session (sign-out and wipes) ───────────────────────
  // Sequences every change of whose data is on this phone. It reaches the
  // engine and the repository only through their narrow interfaces.
  locator.registerLazySingleton<AccountSessionService>(
    () => AccountSessionService(
      authService: locator<AuthService>(),
      sync: locator<SyncEngine>(),
      store: locator<LinkRepository>(),
      remote: locator<CloudSyncService>(),
    ),
  );

  // ─── Sync service (depends on the engine) ───────────────────────
  locator.registerLazySingleton<SyncService>(
    () => SyncService(syncEngine: locator<SyncEngine>()),
  );
}
