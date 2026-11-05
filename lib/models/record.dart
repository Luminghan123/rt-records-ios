import 'dart:convert';

/// 一条"病历首页"记录：按 患者 × 日期 存一条。
/// 所有字段值放在 [data]（JSON）里，新增/改动字段名不需要迁移数据库。
class PatientForm {
  PatientForm({
    this.id,
    required this.uuid,
    required this.date,
    required this.name,
    required this.mrn,
    required this.bedNo,
    required this.data,
    required this.updatedAt,
  });

  int? id;
  final String uuid;
  final String date; // yyyy-MM-dd
  String name;
  String mrn;
  String bedNo;
  Map<String, dynamic> data;
  int updatedAt;

  String get displayName => name.trim().isEmpty ? '未填写姓名' : name.trim();
  String get patientKey => '${name.trim()}|${mrn.trim()}';

  Map<String, Object?> toMap({bool includeId = true}) => {
        if (includeId) 'id': id,
        'uuid': uuid,
        'date': date,
        'name': name,
        'mrn': mrn,
        'bed_no': bedNo,
        'data': jsonEncode(data),
        'updated_at': updatedAt,
      };

  factory PatientForm.fromMap(Map<String, Object?> m) => PatientForm(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        date: m['date'] as String,
        name: (m['name'] as String?) ?? '',
        mrn: (m['mrn'] as String?) ?? '',
        bedNo: (m['bed_no'] as String?) ?? '',
        data: (jsonDecode(m['data'] as String) as Map<String, dynamic>),
        updatedAt: (m['updated_at'] as int?) ?? 0,
      );
}

/// 表头信息（入气道/连接方式/呼吸机）：按 患者 × 日期 × 通气类型 一份
class VentMeta {
  VentMeta({
    this.id,
    required this.formId,
    required this.date,
    required this.type,
    required this.data,
  });

  int? id;
  final int formId;
  final String date;
  final String type;
  Map<String, dynamic> data;

  Map<String, Object?> toMap({bool includeId = true}) => {
        if (includeId) 'id': id,
        'form_id': formId,
        'date': date,
        'type': type,
        'data': jsonEncode(data),
      };

  factory VentMeta.fromMap(Map<String, Object?> m) => VentMeta(
        id: m['id'] as int?,
        formId: m['form_id'] as int,
        date: m['date'] as String,
        type: m['type'] as String,
        data: jsonDecode(m['data'] as String) as Map<String, dynamic>,
      );
}

/// 一个"记录时间点"：对应教程表格里的一列
class VentPoint {
  VentPoint({
    this.id,
    required this.uuid,
    required this.formId,
    required this.date,
    required this.type,
    required this.seq,
    required this.data,
  });

  int? id;
  final String uuid;
  final int formId;
  final String date;
  final String type;
  int seq;
  Map<String, dynamic> data;

  /// 列标题：取时间点，没填就用序号
  String get columnTitle {
    final t = data['time'];
    if (t != null && t.toString().trim().isNotEmpty) return t.toString();
    return '第 $seq 次';
  }

  Map<String, Object?> toMap({bool includeId = true}) => {
        if (includeId) 'id': id,
        'uuid': uuid,
        'form_id': formId,
        'date': date,
        'type': type,
        'seq': seq,
        'data': jsonEncode(data),
      };

  factory VentPoint.fromMap(Map<String, Object?> m) => VentPoint(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        formId: m['form_id'] as int,
        date: m['date'] as String,
        type: m['type'] as String,
        seq: (m['seq'] as int?) ?? 0,
        data: jsonDecode(m['data'] as String) as Map<String, dynamic>,
      );
}
