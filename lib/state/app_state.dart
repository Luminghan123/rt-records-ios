import 'package:flutter/foundation.dart';

import '../data/rt_db.dart';
import '../models/form_schema.dart';
import '../models/record.dart';

/// 全局状态。数据量是"一位治疗师日常记录"级别，
/// 启动时全量读入内存，界面过滤/PDF 导出都不必反复查库。
class AppState extends ChangeNotifier {
  final RtDb _db = RtDb.instance;

  List<PatientForm> _forms = [];
  List<VentMeta> _metas = [];
  List<VentPoint> _points = [];
  bool _loading = true;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<PatientForm> get forms => _forms;
  bool get loading => _loading;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  // ---------- 查询 ----------

  List<PatientForm> formsForDay(DateTime day) {
    final key = dateKey(day);
    return _forms.where((f) => f.date == key).toList(growable: false);
  }

  Set<DateTime> get markedDays =>
      _forms.map((f) => parseDateKey(f.date)).toSet();

  /// 某天有哪些通气类型（日历圆点配色用）
  Set<String> typesForDay(DateTime day) {
    final key = dateKey(day);
    return _metas
        .where((m) => m.date == key)
        .map((m) => m.type)
        .toSet();
  }

  List<FormMetaBundle> eventsForDay(DateTime day) {
    final key = dateKey(day);
    return _forms
        .where((f) => f.date == key)
        .map((f) => FormMetaBundle(f, _metas.where((m) => m.formId == f.id).toList()))
        .toList(growable: false);
  }

  VentMeta? metaFor(int? formId, String date, String type) {
    if (formId == null) return null;
    for (final m in _metas) {
      if (m.formId == formId && m.date == date && m.type == type) return m;
    }
    return null;
  }

  List<VentPoint> pointsFor(int? formId, String date, String type) {
    if (formId == null) return const [];
    final list = _points
        .where((r) =>
            r.formId == formId && r.date == date && r.type == type)
        .toList();
    list.sort((a, b) => a.seq.compareTo(b.seq));
    return list;
  }

  int pointCount(int? formId, String date, String type) =>
      pointsFor(formId, date, type).length;

  /// 历史患者（按 姓名+病历号 去重，取最近一次填过的病历首页）
  List<PatientForm> patientHistory() {
    final map = <String, PatientForm>{};
    for (final f in _forms) {
      final key = f.patientKey;
      final prev = map[key];
      if (prev == null || f.date.compareTo(prev.date) >= 0) map[key] = f;
    }
    final list = map.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 单患者全疗程（从入院到拔管，按日期升序）
  List<PatientForm> allFormsForPatient(String key) {
    final list = _forms.where((f) => f.patientKey == key).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<PatientForm> formsInRange(DateTime from, DateTime to) {
    final a = dateKey(from);
    final b = dateKey(to);
    final list = _forms
        .where((f) => f.date.compareTo(a) >= 0 && f.date.compareTo(b) <= 0)
        .toList();
    list.sort((x, y) => x.date.compareTo(y.date));
    return list;
  }

  // ---------- 写入 ----------

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _forms = await _db.allForms();
    _metas = await _db.allMeta();
    _points = await _db.allPoints();
    _loading = false;
    notifyListeners();
  }

  Future<int> saveForm(PatientForm f) async {
    final id = await _db.upsertForm(f);
    f.id = id;
    await load();
    return id;
  }

  Future<void> deleteForm(int id) async {
    await _db.deleteForm(id);
    await load();
  }

  /// 一次性保存通气页：表头 + 全部时间点
  Future<void> saveVent({
    required PatientForm form,
    required String type,
    required Map<String, dynamic> metaData,
    required List<Map<String, dynamic>> points,
  }) async {
    final db = _db;
    final meta = VentMeta(
      id: metaFor(form.id, form.date, type)?.id,
      formId: form.id!,
      date: form.date,
      type: type,
      data: Map<String, dynamic>.from(metaData),
    );
    await db.upsertMeta(meta);

    // 旧的时间点列全部删掉再写入，保证顺序与界面一致
    for (final old in pointsFor(form.id, form.date, type)) {
      if (old.id != null) await db.deletePoint(old.id!);
    }
    var seq = 1;
    for (final data in points) {
      await db.upsertPoint(VentPoint(
        uuid: '${DateTime.now().microsecondsSinceEpoch}-$seq',
        formId: form.id!,
        date: form.date,
        type: type,
        seq: seq,
        data: Map<String, dynamic>.from(data),
      ));
      seq++;
    }
    await load();
  }

  Future<void> clearAll() async {
    await _db.clearAll();
    await load();
  }

  // ---------- 日历 ----------

  void selectDay(DateTime day) {
    final sel = _selectedDay;
    _selectedDay = (sel != null && dateKey(sel) == dateKey(day)) ? null : day;
    notifyListeners();
  }

  void setFocusedDay(DateTime day) {
    _focusedDay = day;
    notifyListeners();
  }

  void resetToToday() {
    _focusedDay = DateTime.now();
    _selectedDay = null;
    notifyListeners();
  }
}

/// 首页日历的 event 载荷：某天某患者及其通气类型
class FormMetaBundle {
  const FormMetaBundle(this.form, this.metas);
  final PatientForm form;
  final List<VentMeta> metas;
}
