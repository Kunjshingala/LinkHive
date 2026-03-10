import 'package:hive_flutter/hive_flutter.dart';

import 'link_model.dart';

/// Manually written Hive [TypeAdapter] for [LinkModel].
///
/// This adapter is registered at app startup (in `main.dart` or the Hive
/// initialization code) so Hive knows how to serialize and deserialize
/// [LinkModel] objects when reading from / writing to the links box.
///
/// ## Why manually written (not generated)?
/// The standard `hive_generator` package writes adapters from `@HiveType` /
/// `@HiveField` annotations on the model class. However, [LinkModel] is also
/// serialized to Firestore, so it deliberately avoids Hive-specific
/// annotations to keep the model layer clean. The adapter is therefore written
/// by hand and kept in sync manually.
///
/// ## Field Index Map
/// Each field is assigned a stable integer index. **Never reuse or reorder
/// these indices** — doing so would corrupt existing data stored on user
/// devices.
///
/// | Index | Field        | Dart type |
/// |-------|-------------|-----------|
/// | 0     | id           | String    |
/// | 1     | url          | String    |
/// | 2     | title        | String    |
/// | 3     | description  | String    |
/// | 4     | image        | String    |
/// | 5     | categories   | `List<String>` |
/// | 6     | priority     | String    |
/// | 7     | createdAt    | int (UTC ms) |
/// | 8     | isSynced     | bool      |
/// | 9     | syncedAt     | int? (UTC ms) |
///
/// ## Adding a new field
/// 1. Add the field to [LinkModel] with a sensible default.
/// 2. Pick the **next available index** (currently `10`).
/// 3. Add `reader.readByte(): reader.read()` to [read] and handle the new
///    index with a safe cast + default value.
/// 4. Add `..writeByte(N) ..write(obj.newField)` to [write].
/// 5. Increment the `writeByte` count at the top of [write] body.
class LinkModelAdapter extends TypeAdapter<LinkModel> {
  /// The unique Hive type ID for [LinkModel].
  ///
  /// Must be unique across all registered adapters in the app.
  /// **Do not change this value** after the app has been shipped — changing
  /// it would prevent Hive from reading previously stored data.
  @override
  final int typeId = 0;

  /// Reads a [LinkModel] from the binary Hive storage.
  ///
  /// The binary format written by [write] starts with a byte containing the
  /// number of fields, followed by alternating (fieldIndex, value) pairs.
  /// The `fields` map is built first so that reads are order-independent —
  /// older data that is missing a field simply won't have that key in the map,
  /// and a safe default is applied via `?? defaultValue`.
  @override
  LinkModel read(BinaryReader reader) {
    // RESILIENCE: the entire deserialization is wrapped in try/catch.
    //
    // If ANY record in the Hive box fails to deserialize (type mismatch,
    // missing field, schema change, corrupted bytes, etc.), Hive would
    // otherwise throw during box initialization and the app would crash
    // on startup before the UI is ever rendered.
    //
    // By catching the error here and returning a safe fallback model instead,
    // the bad record is silently skipped. The rest of the box opens normally
    // and the app continues. The fallback has isSynced=false, so if the user
    // is authenticated the SyncService will pull the correct data from
    // Firestore on the next sync cycle.
    try {
      final numOfFields = reader.readByte();

      // Build a map of type `Map<int, dynamic>` from field index → value.
      // This approach is forward-compatible: if an older version of the model
      // wrote fewer fields, the missing keys will simply be absent from the map
      // and the defaults below will kick in.
      final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};

      return LinkModel(
        id: fields[0] as String,
        url: fields[1] as String,
        title: fields[2] as String,
        description: fields[3] as String? ?? '',
        image: fields[4] as String? ?? '',
        categories: (fields[5] as List?)?.cast<String>() ?? [],
        priority: fields[6] as String? ?? 'Normal',
        // _toEpochMs handles backward compatibility: old records stored DateTime,
        // new records store int. Falls back to now() if the field is missing.
        createdAt: _toEpochMs(fields[7]) ?? DateTime.now().toUtc().millisecondsSinceEpoch,
        isSynced: fields[8] as bool? ?? false,
        syncedAt: _toEpochMs(fields[9]), // Null for links not yet synced.
      );
    } catch (e, stack) {
      // Log clearly so the developer can diagnose the root cause in logcat /
      // console, then return a minimal valid model instead of crashing.
      // ignore: avoid_print
      print('[LinkModelAdapter] Failed to deserialize record — returning fallback. Error: $e\n$stack');

      return LinkModel(
        id: 'corrupt_${DateTime.now().millisecondsSinceEpoch}',
        url: '',
        title: '[Unreadable link]',
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        isSynced: false,
      );
    }
  }

  /// Converts a value read from Hive storage to a UTC milliseconds-since-epoch
  /// integer, handling both the old [DateTime] format and the current [int] format.
  ///
  /// **Why this exists**: Before the epoch-int refactor, `createdAt` and
  /// `syncedAt` were written as `DateTime` objects by an earlier version of
  /// the adapter. Devices that already have stored data will encounter those
  /// `DateTime` values when reading back from Hive, so a direct `as int?`
  /// cast would crash with a `type 'DateTime' is not a subtype of type 'int?'`
  /// error. This helper handles both cases transparently.
  ///
  /// Returns:
  /// - The [int] directly if [value] is already an `int`.
  /// - `DateTime.millisecondsSinceEpoch` (UTC) if [value] is a `DateTime`.
  /// - `null` if [value] is `null` or any other unexpected type.
  int? _toEpochMs(dynamic value) {
    if (value is int) return value;
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    return null;
  }

  /// Writes a [LinkModel] to binary Hive storage.
  ///
  /// The first `writeByte(10)` call tells Hive how many fields follow.
  /// Each field is written as a (index byte, value) pair. The order of
  /// pairs in the binary stream does not matter to [read] because [read]
  /// rebuilds a keyed map before constructing the object.
  ///
  /// **Keep the leading count byte in sync with the actual number of fields.**
  @override
  void write(BinaryWriter writer, LinkModel obj) {
    writer
      ..writeByte(10) // Total number of fields stored (must match the pairs below).
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
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.syncedAt);
  }

  // ─── Equality ─────────────────────────────────────────────────────────────
  // Hive requires TypeAdapter subclasses to implement equality so it can
  // deduplicate adapter registrations. Two adapters are equal when they
  // share the same [typeId] (and therefore represent the same type).

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LinkModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
