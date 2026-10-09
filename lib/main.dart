import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ─── Font licenses (OFL requires shipping them with the fonts) ───
  LicenseRegistry.addLicense(_fontLicenses);

  runApp(const MyApp());
}

/// The bundled typefaces' licenses, shown on Flutter's license page.
Stream<LicenseEntry> _fontLicenses() async* {
  yield LicenseEntryWithLineBreaks(
    const ['Anek Latin', 'Anek Devanagari', 'Anek Gujarati'],
    await rootBundle.loadString('assets/licenses/OFL-Anek.txt'),
  );
  yield LicenseEntryWithLineBreaks(
    const ['Readex Pro'],
    await rootBundle.loadString('assets/licenses/OFL-ReadexPro.txt'),
  );
}
