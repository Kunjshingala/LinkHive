// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Points `getApplicationDocumentsDirectory()` at a temp directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('linkhive-helper-test-');
    PathProviderPlatform.instance = _FakePathProvider(directory.path);
    Hive.init(directory.path);
    await (await Hive.openBox(
      HiveConstants.settingsBox,
    )).put(HiveConstants.lastPulledAtKey, 12345);
  });

  tearDown(() async {
    await Hive.close();
    // init() registers the model adapters, and registrations outlive a test.
    Hive.resetAdapters();
    await directory.delete(recursive: true);
  });

  test('readable link boxes keep the pull cursor', () async {
    await HiveHelper().init();

    expect(HiveHelper().settingsBox.get(HiveConstants.lastPulledAtKey), 12345);
  });

  test(
    'rebuilding link boxes that cannot be opened also drops the pull cursor, '
    'so the next pull is a full fetch',
    () async {
      // `links_box` is already open as an untyped box, so opening it as a
      // `Box<LinkModel>` throws and sends init() down the rebuild path.
      await Hive.openBox(HiveConstants.linksBox);

      await HiveHelper().init();

      final helper = HiveHelper();
      expect(helper.linksBox.isEmpty, isTrue);
      expect(helper.settingsBox.get(HiveConstants.lastPulledAtKey), isNull);
    },
  );
}
