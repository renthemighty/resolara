import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

class Visualizations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text()();
  TextColumn get imagePath => text()();
  IntColumn get createdAt => integer()(); // ms since epoch
  TextColumn get bodyRegions => text()(); // JSON-encoded string list
  IntColumn get findingCount => integer()();
  IntColumn get retainUntil => integer().nullable()(); // ms since epoch, null = keep forever
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Visualizations])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // ── Queries ──────────────────────────────────────────────────────────────

  Stream<List<Visualization>> watchAll() =>
      (select(visualizations)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<Visualization?> getById(int id) =>
      (select(visualizations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertVisualization(VisualizationsCompanion entry) =>
      into(visualizations).insert(entry);

  Future<void> deleteVisualization(int id) =>
      (delete(visualizations)..where((t) => t.id.equals(id))).go();

  Future<void> cleanupExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (delete(visualizations)
          ..where((t) => t.retainUntil.isNotNull() & t.retainUntil.isSmallerThanValue(now)))
        .go();
  }
}

// ---------------------------------------------------------------------------
// Singleton opener
// ---------------------------------------------------------------------------

AppDatabase? _dbInstance;

Future<AppDatabase> openAppDatabase() async {
  if (_dbInstance != null) return _dbInstance!;

  const storage = FlutterSecureStorage();
  const keyName = 'resolara_db_key';

  // Generate and persist a DB key on first run (for future SQLCipher use)
  var dbKey = await storage.read(key: keyName);
  if (dbKey == null) {
    // Simple random key using Dart's DateTime + hash — replace with
    // crypto-random bytes when adding SQLCipher in Phase 2
    dbKey = DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
        Object().hashCode.toRadixString(16);
    await storage.write(key: keyName, value: dbKey);
  }

  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'resolara.db'));

  _dbInstance = AppDatabase(NativeDatabase(dbFile));
  await _dbInstance!.cleanupExpired();
  return _dbInstance!;
}
