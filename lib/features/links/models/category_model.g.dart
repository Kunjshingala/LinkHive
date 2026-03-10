import 'package:hive_flutter/hive_flutter.dart';

import 'category_model.dart';

/// Manually written Hive [TypeAdapter] for [CategoryModel].
///
/// ## Field Index Map
/// | Index | Field | Dart type |
/// |-------|-------|-----------|
/// | 0     | id    | String    |
/// | 1     | name  | String    |
class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = 1;

  /// Reads a [CategoryModel] from binary Hive storage.
  ///
  /// Wrapped in try/catch for resilience: if the stored bytes are corrupted
  /// or from an incompatible schema version, a fallback model is returned
  /// instead of throwing — which would otherwise prevent the entire box from
  /// opening and crash the app at startup.
  @override
  CategoryModel read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
      return CategoryModel(id: fields[0] as String, name: fields[1] as String? ?? '');
    } catch (e, stack) {
      // ignore: avoid_print
      print('[CategoryModelAdapter] Failed to deserialize record — returning fallback. Error: $e\n$stack');
      return CategoryModel(id: 'corrupt_${DateTime.now().millisecondsSinceEpoch}', name: '');
    }
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
