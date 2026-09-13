// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_tombstone.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncTombstoneAdapter extends TypeAdapter<SyncTombstone> {
  @override
  final int typeId = 3;

  @override
  SyncTombstone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncTombstone(
      entityType: fields[0] as String,
      entityId: fields[1] as String,
      deletedAt: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SyncTombstone obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.entityType)
      ..writeByte(1)
      ..write(obj.entityId)
      ..writeByte(2)
      ..write(obj.deletedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTombstoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
