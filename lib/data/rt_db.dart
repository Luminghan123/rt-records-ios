import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/record.dart';

/// 本地 SQLite。三张表：
/// - patient_form  病历首页（患者 × 日期）
/// - vent_meta     通气表头信息（患者 × 日期 × 类型）
/// - vent_point    记录时间点（表格里的一列）
class RtDb {
  RtDb._();
  static final RtDb instance = RtDb._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'rt_records.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE patient_form(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            date TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            mrn TEXT NOT NULL DEFAULT '',
            bed_no TEXT NOT NULL DEFAULT '',
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_form_date ON patient_form(date)');
        await db.execute('CREATE INDEX idx_form_patient ON patient_form(name, mrn)');
        await db.execute('''
          CREATE TABLE vent_meta(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            form_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            UNIQUE(form_id, date, type)
          )
        ''');
        await db.execute('''
          CREATE TABLE vent_point(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            form_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            seq INTEGER NOT NULL,
            data TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_point_form ON vent_point(form_id, date, type)',
        );
      },
    );
    _db = db;
    return db;
  }

  // ---------- 病历首页 ----------
  Future<List<PatientForm>> allForms() async {
    final db = await _database;
    final rows = await db.query('patient_form', orderBy: 'date ASC, id ASC');
    return rows.map(PatientForm.fromMap).toList();
  }

  Future<int> upsertForm(PatientForm f) async {
    final db = await _database;
    if (f.id == null) {
      return db.insert('patient_form', f.toMap(includeId: false));
    }
    await db.update('patient_form', f.toMap(includeId: false),
        where: 'id = ?', whereArgs: [f.id]);
    return f.id!;
  }

  Future<void> deleteForm(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('vent_point', where: 'form_id = ?', whereArgs: [id]);
      await txn.delete('vent_meta', where: 'form_id = ?', whereArgs: [id]);
      await txn.delete('patient_form', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- 通气表头 ----------
  Future<List<VentMeta>> allMeta() async {
    final db = await _database;
    final rows = await db.query('vent_meta');
    return rows.map(VentMeta.fromMap).toList();
  }

  Future<void> upsertMeta(VentMeta m) async {
    final db = await _database;
    await db.insert(
      'vent_meta',
      m.toMap(includeId: false),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- 记录时间点 ----------
  Future<List<VentPoint>> allPoints() async {
    final db = await _database;
    final rows = await db.query('vent_point', orderBy: 'date ASC, seq ASC');
    return rows.map(VentPoint.fromMap).toList();
  }

  Future<int> upsertPoint(VentPoint r) async {
    final db = await _database;
    if (r.id == null) {
      return db.insert('vent_point', r.toMap(includeId: false));
    }
    await db.update('vent_point', r.toMap(includeId: false),
        where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> deletePoint(int id) async {
    final db = await _database;
    await db.delete('vent_point', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('vent_point');
      await txn.delete('vent_meta');
      await txn.delete('patient_form');
    });
  }
}
