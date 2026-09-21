// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LinkModelAdapter extends TypeAdapter<LinkModel> {
  @override
  final int typeId = 0;

  @override
  LinkModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LinkModel(
      id: fields[0] as String,
      url: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String,
      image: fields[4] as String,
      categories: (fields[5] as List).cast<String>(),
      priority: fields[6] as String,
      createdAt: fields[7] as int,
      syncedAt: fields[8] as int?,
      isSynced: fields[9] as bool,
      // Null-safe fallback: field 10 is absent in records written before isRead
      // was added. build_runner generates a non-nullable cast (as bool) which
      // crashes on those old records, so we use `as bool? ?? false` here.
      isRead: fields[10] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, LinkModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.categories)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.syncedAt)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
