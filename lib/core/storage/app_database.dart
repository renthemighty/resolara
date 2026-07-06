import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

class PatientSavedResults extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get shareCode  => text()();
  TextColumn get patientName => text().nullable()();
  IntColumn  get savedAt   => integer()(); // ms since epoch
}

class Visualizations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text()();
  TextColumn get imagePath => text()();
  IntColumn get createdAt => integer()(); // ms since epoch
  TextColumn get bodyRegions => text()(); // comma-separated
  IntColumn get findingCount => integer()();
  IntColumn get retainUntil => integer().nullable()(); // ms since epoch
  TextColumn get patientLabel => text().nullable()();
}

/// Tracks every generation attempt — active, completed, and failed.
/// Used for session resumption and analytics (token usage, cost).
class Sessions extends Table {
  TextColumn get id => text()(); // local UUID
  TextColumn get vizJobId => text().nullable()(); // server /v1/visualizations job ID
  TextColumn get status => text()(); // generating | completed | failed
  TextColumn get findingsJson => text().nullable()(); // serialised for resumption
  TextColumn get bodyRegions => text().withDefault(const Constant(''))();
  IntColumn get findingCount => integer().withDefault(const Constant(0))();
  IntColumn get startedAt => integer()(); // ms
  IntColumn get updatedAt => integer()(); // ms
  IntColumn get tokensIn => integer().withDefault(const Constant(0))();
  IntColumn get tokensOut => integer().withDefault(const Constant(0))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PatientReminders extends Table {
  IntColumn  get id            => integer().autoIncrement()();
  TextColumn get shareCode     => text()();
  TextColumn get itemId        => text()();       // medication or exercise ID
  TextColumn get itemType      => text()();       // 'medication' or 'exercise'
  TextColumn get itemName      => text()();
  IntColumn  get reminderHour  => integer()();
  IntColumn  get reminderMinute => integer()();
  BoolColumn get enabled       => boolean().withDefault(const Constant(true))();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Visualizations, Sessions, PatientSavedResults, PatientReminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sessions);
          }
          if (from < 3) {
            await m.addColumn(visualizations, visualizations.patientLabel);
          }
          if (from >= 2 && from < 4) {
            // Guard against duplicate-column errors: earlier builds may have
            // created the sessions table with these columns already present.
            try { await m.addColumn(sessions, sessions.tokensIn); } catch (_) {}
            try { await m.addColumn(sessions, sessions.tokensOut); } catch (_) {}
          }
          if (from < 5) {
            await m.createTable(patientSavedResults);
          }
          if (from < 6) {
            await m.createTable(patientReminders);
          }
        },
      );

  // ── Visualizations ────────────────────────────────────────────────────────

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
          ..where((t) =>
              t.retainUntil.isNotNull() &
              t.retainUntil.isSmallerThanValue(now)))
        .go();
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Stream<List<Session>> watchSessions() =>
      (select(sessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  Future<Session?> getSession(String id) =>
      (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry);

  Future<void> updateSession(SessionsCompanion entry) =>
      (update(sessions)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deleteSession(String id) =>
      (delete(sessions)..where((t) => t.id.equals(id))).go();

  Future<List<Session>> getActiveSessions() =>
      (select(sessions)
            ..where((t) => t.status.equals('generating'))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  // ── Patient Saved Results ─────────────────────────────────────────────────

  Stream<List<PatientSavedResult>> watchPatientSaved() =>
      (select(patientSavedResults)
            ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]))
          .watch();

  Future<PatientSavedResult?> getPatientSaved(String code) =>
      (select(patientSavedResults)
            ..where((t) => t.shareCode.equals(code.toUpperCase())))
          .getSingleOrNull();

  Future<void> insertPatientSaved(PatientSavedResultsCompanion entry) =>
      into(patientSavedResults).insert(entry);

  Future<void> deletePatientSaved(String code) =>
      (delete(patientSavedResults)
            ..where((t) => t.shareCode.equals(code.toUpperCase())))
          .go();

  // ── Patient Reminders ────────────────────────────────────────────────────

  Future<List<PatientReminder>> getRemindersForShare(String shareCode) =>
      (select(patientReminders)
            ..where((t) => t.shareCode.equals(shareCode)))
          .get();

  Future<PatientReminder?> getReminder(String shareCode, String itemId, String itemType) =>
      (select(patientReminders)
            ..where((t) =>
                t.shareCode.equals(shareCode) &
                t.itemId.equals(itemId) &
                t.itemType.equals(itemType)))
          .getSingleOrNull();

  Future<int> insertReminder(PatientRemindersCompanion entry) =>
      into(patientReminders).insert(entry);

  Future<void> deleteReminder(String shareCode, String itemId, String itemType) =>
      (delete(patientReminders)
            ..where((t) =>
                t.shareCode.equals(shareCode) &
                t.itemId.equals(itemId) &
                t.itemType.equals(itemType)))
          .go();
}

// ---------------------------------------------------------------------------
// Singleton opener
// ---------------------------------------------------------------------------

AppDatabase? _dbInstance;

Future<AppDatabase> openAppDatabase() async {
  if (_dbInstance != null) return _dbInstance!;

  const storage = FlutterSecureStorage();
  const keyName = 'resolara_db_key';

  var dbKey = await storage.read(key: keyName);
  if (dbKey == null) {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    dbKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: keyName, value: dbKey);
  }

  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'resolara.db'));

  _dbInstance = AppDatabase(NativeDatabase(dbFile));
  await _dbInstance!.cleanupExpired();
  return _dbInstance!;
}
