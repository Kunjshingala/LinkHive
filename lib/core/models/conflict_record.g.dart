// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConflictRecordAdapter extends TypeAdapter<ConflictRecord> {
  @override
  final int typeId = 4;

  @override
  ConflictRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConflictRecord(
      conflictId: fields[0] as String,
      linkId: fields[1] as String,
      conflictingFields: (fields[2] as List).cast<String>(),
      baseVersion: (fields[3] as Map).cast<String, dynamic>(),
      localVersion: (fields[4] as Map).cast<String, dynamic>(),
      cloudVersion: (fields[5] as Map?)?.cast<String, dynamic>(),
      createdAt: fields[6] as int,
      status: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ConflictRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.conflictId)
      ..writeByte(1)
      ..write(obj.linkId)
      ..writeByte(2)
      ..write(obj.conflictingFields)
      ..writeByte(3)
      ..write(obj.baseVersion)
      ..writeByte(4)
      ..write(obj.localVersion)
      ..writeByte(5)
      ..write(obj.cloudVersion)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
