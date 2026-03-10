import 'package:hive_flutter/hive_flutter.dart';

import '../../features/links/models/category_model.g.dart';
import '../../features/links/models/category_model.dart';
import '../../features/links/models/link_model.g.dart';
import '../../features/links/models/link_model.dart';

import '../constants/hive_constants.dart';

class HiveHelper {
  /// Initialize Hive, register adapters, and open all required boxes.
  /// This should be called once in main().
  Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());

    // Open Boxes
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
  }

  // Box Getters
  Box get settingsBox => Hive.box(HiveConstants.settingsBox);
  Box<LinkModel> get linksBox => Hive.box<LinkModel>(HiveConstants.linksBox);
  Box<CategoryModel> get categoriesBox => Hive.box<CategoryModel>(HiveConstants.categoriesBox);
}
