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
      isRead: fields[10] as bool,
      isQuickSaved: fields[11] == null ? false : fields[11] as bool,
      resurfaceAt: fields[12] as int?,
      lastResurfacedAt: fields[13] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LinkModel obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.isRead)
      ..writeByte(11)
      ..write(obj.isQuickSaved)
      ..writeByte(12)
      ..write(obj.resurfaceAt)
      ..writeByte(13)
      ..write(obj.lastResurfacedAt);
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
