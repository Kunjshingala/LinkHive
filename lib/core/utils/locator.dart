import 'package:get_it/get_it.dart';

import '../../features/links/repository/link_repository.dart';
import '../services/auth_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/link_metadata_service.dart';
import '../services/receive_shared_intent.dart';
import '../services/sync_service.dart';
import 'hive_helper.dart';

final locator = GetIt.instance;

void setupLocator() {
  // ─── Auth & Intent services ─────────────────────────────────────
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<ReceiveSharedIntent>(() => ReceiveSharedIntent());

  // ─── Firebase / Cloud ───────────────────────────────────────────
  locator.registerLazySingleton<FirebaseFirestoreService>(() => FirebaseFirestoreService());

  // ─── Hive ─────────────────────────────────────────────────────────
  locator.registerLazySingleton<HiveHelper>(() => HiveHelper());

  // ─── Metadata ───────────────────────────────────────────────────
  locator.registerLazySingleton<LinkMetadataService>(() => LinkMetadataService());

  // ─── Repository ─────────────────────────────────────────────────
  locator.registerLazySingleton<LinkRepository>(
    () => LinkRepository(firebaseService: locator<FirebaseFirestoreService>(), hiveHelper: locator<HiveHelper>()),
  );

  // ─── Sync service (depends on repository) ───────────────────────
  locator.registerLazySingleton<SyncService>(() => SyncService(linkRepository: locator<LinkRepository>()));
}
