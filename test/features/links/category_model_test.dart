import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/constants/firebase_constants.dart';
import 'package:link_hive/features/links/models/category_model.dart';

void main() {
  group('CategoryModel', () {
    const testCategory = CategoryModel(id: 'cat-id', name: 'Flutter');

    test('toFirestore returns correct map containing name', () {
      final map = testCategory.toFirestore();

      expect(map[FirebaseConstants.categoryName], 'Flutter');
      expect(map.containsKey('id'), false); // 'id' shouldn't be in the map
    });

    test('fromFirestore correctly parses valid data', () {
      final data = {FirebaseConstants.categoryName: 'Dart'};

      final category = CategoryModel.fromFirestore('new-cat-id', data);

      expect(category.id, 'new-cat-id');
      expect(category.name, 'Dart');
    });

    test('fromFirestore handles missing name gracefully', () {
      final data = <String, dynamic>{};

      final category = CategoryModel.fromFirestore('missing-name-cat-id', data);

      expect(category.id, 'missing-name-cat-id');
      expect(category.name, '');
    });
  });
}
