import 'package:get_it/get_it.dart';

import '../../features/links/repository/link_repository.dart';
import '../services/auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/link_metadata_service.dart';
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
      repository: locator<LinkRepository>(),
      metadataService: locator<LinkMetadataService>(),
    ),
  );
  locator.registerLazySingleton<ResurfaceNotificationService>(
    () => ResurfaceNotificationService(),
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
    () => LinkRepository(
      firebaseService: locator<FirebaseFirestoreService>(),
      hiveHelper: locator<HiveHelper>(),
    ),
  );

  locator.registerLazySingleton<SyncEngine>(
    () => SyncEngine(repository: locator<LinkRepository>()),
  );

  // ─── Sync service (depends on repository) ───────────────────────
  locator.registerLazySingleton<SyncService>(
    () => SyncService(
      linkRepository: locator<LinkRepository>(),
      syncEngine: locator<SyncEngine>(),
    ),
  );
}
