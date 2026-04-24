import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/services/sync_service.dart';
import 'core/utils/bloc_observer.dart';
import 'core/utils/hive_helper.dart';
import 'core/utils/locator.dart';
import 'firebase_options.dart';
import 'my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Firebase ────────────────────────────────────────────────────
  await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);

  // ─── Dependency Injection ────────────────────────────────────────
  setupLocator();

  // ─── BLoC Observer ───────────────────────────────────────────────
  Bloc.observer = AppBlocObserver();

  // ─── Hive (local-first storage) ──────────────────────────────────
  await locator<HiveHelper>().init();

  // ─── Start background sync listener ──────────────────────────────
  locator<SyncService>().startListening();

  runApp(const MyApp());
}
