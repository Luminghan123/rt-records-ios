/// 三张表（教程附录Ⅱ）的字段定义 —— 全 App 唯一的一份字段清单。
///
/// 界面表单、PDF 表格、跨天复用的数据键，都从这里生成，
/// 保证"录入项"和"导出项"一字不差，不会出现界面有、PDF 漏的情况。
library;

enum FieldKind {
  text, // 单行文字
  number, // 数字（软键盘带数字）
  yesNo, // 是 / 否
  choice, // 单选
  multi, // 多选（勾选）
  dateTime, // 日期时间
  longText, // 多行文字
}

class FormField {
  const FormField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.unit,
    this.options,
    this.hint,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final String? unit;
  final List<String>? options;
  final String? hint;

  /// 界面与 PDF 上显示的完整标签（带单位）
  String get displayLabel => unit == null ? label : '$label（$unit）';
}

class FormGroup {
  const FormGroup(this.name, this.fields);

  final String name;
  final List<FormField> fields;
}

// ============================================================
// 一、呼吸治疗病历首页（教程附录Ⅱ，PDF 257 / 印刷 253）
// ============================================================
const List<FormGroup> kPatientGroups = [
  FormGroup('基本信息', [
    FormField('name', '姓名'),
    FormField('sex', '性别', kind: FieldKind.choice, options: ['男', '女']),
    FormField('age', '年龄', kind: FieldKind.number, unit: '岁'),
    FormField('bed_no', '床号'),
    FormField('mrn', '病历号'),
  ]),
  FormGroup('时间', [
    FormField('icu_in', '入 ICU 时间', kind: FieldKind.dateTime),
    FormField('record_time', '记录时间', kind: FieldKind.dateTime),
  ]),
  FormGroup('主诉', [
    FormField('symptom_resp', '呼吸系统症状', kind: FieldKind.multi,
        options: ['咳嗽咳痰', '胸痛', '呼吸困难', '咯血']),
    FormField('symptom_other', '其他系统症状', kind: FieldKind.longText),
    FormField('past_history', '既往史', kind: FieldKind.longText),
  ]),
  FormGroup('查体', [
    FormField('t', 'T', kind: FieldKind.number, unit: '℃'),
    FormField('hr', 'HR', kind: FieldKind.number, unit: '次/分'),
    FormField('rr', 'RR', kind: FieldKind.number, unit: '次/分'),
    FormField('bp', 'Bp', unit: 'mmHg'),
    FormField('spo2', 'SpO₂', kind: FieldKind.number, unit: '%'),
    FormField('pe_look', '视诊', kind: FieldKind.longText),
    FormField('pe_touch', '触诊', kind: FieldKind.longText),
    FormField('pe_percuss', '叩诊', kind: FieldKind.longText),
    FormField('pe_listen', '听诊', kind: FieldKind.longText),
    FormField('pe_other', '其他系统', kind: FieldKind.longText),
    FormField('nutrition', '营养状态', kind: FieldKind.longText),
  ]),
  FormGroup('辅助检查', [
    FormField('wbc', 'WBC', unit: '×10⁹/L'),
    FormField('n', 'N', unit: '%'),
    FormField('hb', 'Hb', unit: 'g/dL'),
    FormField('rbc', 'RBC', unit: '×10¹²/L'),
    FormField('plt', 'PLT', unit: '×10⁹/L'),
    FormField('cxr', '胸部 X 片', kind: FieldKind.longText),
    FormField('ct', '胸部 CT', kind: FieldKind.longText),
    FormField('abg_ph', 'pH'),
    FormField('abg_pao2', 'PaO₂'),
    FormField('abg_paco2', 'PaCO₂'),
    FormField('abg_hco3', 'HCO₃⁻'),
    FormField('abg_be', 'BE'),
    FormField('abg_fio2', 'FiO₂'),
    FormField('bio_tp', 'TP'),
    FormField('bio_ast', 'AST'),
    FormField('bio_alt', 'ALT'),
    FormField('bio_bun', 'BUN'),
    FormField('bio_crea', 'Crea'),
    FormField('bio_na', 'Na⁺'),
    FormField('bio_k', 'K⁺'),
    FormField('bio_cl', 'Cl⁻'),
    FormField('bio_ca', 'Ca²⁺'),
    FormField('lab_other', '其他', kind: FieldKind.longText),
  ]),
  FormGroup('诊断', [
    FormField('diagnosis', '诊断', kind: FieldKind.longText),
  ]),
  FormGroup('呼吸支持', [
    FormField('support_way', '方式', kind: FieldKind.multi, options: [
      '鼻导管',
      '文丘里面罩',
      '储氧面罩',
      'NPPV',
      '有创通气',
    ]),
    FormField('o2', '氧浓度/流量'),
    FormField('vent_model', '呼吸机型号'),
    FormField('vent_mode', '设置模式'),
    FormField('vent_params', '设置参数', kind: FieldKind.longText),
    FormField('vent_monitor', '监测参数', kind: FieldKind.longText),
  ]),
  FormGroup('呼吸治疗计划', [
    FormField('plan', '计划', kind: FieldKind.longText),
    FormField('signature', '签名'),
  ]),
];

// ============================================================
// 二、有创通气（PDF 258 / 印刷 254）
// kInvasiveMeta = 表头（入气道/呼吸机信息，一天一份）
// kInvasivePoint = 每次记录时间点的一列
// ============================================================
const List<FormGroup> kInvasiveMeta = [
  FormGroup('入气道 / 呼吸机信息', [
    FormField('main_diagnosis', '主要诊断', kind: FieldKind.longText),
    FormField('airway', '人工气道', kind: FieldKind.choice,
        options: ['气管插管', '气管切开']),
    FormField('airway_days', '建立第', kind: FieldKind.number, unit: '天'),
    FormField('start_days', '开始第', kind: FieldKind.number, unit: '天'),
    FormField('tube_mm', '导管外露距离', unit: 'mm'),
    FormField('vent_name', '呼吸机名称'),
    FormField('mode', '模式'),
    FormField('params', '参数', kind: FieldKind.longText),
  ]),
];

const List<FormGroup> kInvasivePoint = [
  FormGroup('心电监护', [
    FormField('time', '时间', kind: FieldKind.dateTime),
    FormField('hr', 'HR', kind: FieldKind.number, unit: '次/分'),
    FormField('bp', 'BP', unit: 'mmHg'),
    FormField('spo2', 'SpO₂', kind: FieldKind.number, unit: '%'),
    FormField('mode', 'MODE'),
  ]),
  FormGroup('机械通气监测', [
    FormField('vt', 'VT set/meas'),
    FormField('rr', 'RR set/meas'),
    FormField('mv', 'MV'),
    FormField('ppeak', 'Ppeak set/meas'),
    FormField('pplat', 'Pplat / Pmean'),
    FormField('peep', 'PEEP / PEEPi'),
    FormField('cstat', 'Cstat / Cdyn'),
    FormField('rinsp', 'Rinsp（吸气时间）'), // 用户纠正：原扫描件读作 Rsus
    FormField('wave', 'Wave Form'),
    FormField('pip_peep', 'PIP / PEEP'),
  ]),
  FormGroup('报警 / 监测', [
    FormField('high_ppeak', 'High Ppeak（气道高压报警）'), // 用户纠正
    FormField('high_low_vt', 'High/Low VT'),
    FormField('high_low_mv', 'High/Low MV'),
  ]),
  FormGroup('人工气道监测', [
    FormField('tube_out', '导管外露距离'),
    FormField('humid_water', '湿化器水位'),
    FormField('y_temp', 'Y 形管温度'),
    FormField('sputum', '痰液颜色/黏稠度'),
    FormField('suction', '吸痰频率'),
  ]),
  FormGroup('撤机', [
    FormField('rtw', '是否通过 RTW（具备撤机条件）', kind: FieldKind.yesNo),
    FormField('extubated', '是否拔管', kind: FieldKind.yesNo),
    FormField('weaning_trial', '是否脱机锻炼', kind: FieldKind.yesNo),
    FormField('weaning_time', '脱机时间', kind: FieldKind.dateTime),
    FormField('extub_time', '拔管时间', kind: FieldKind.dateTime),
    FormField('vent_days', '带机时间'),
    FormField('assessment', '相关操作和评估记录', kind: FieldKind.longText),
  ]),
  FormGroup('血气分析', [
    FormField('abg_time', '时间', kind: FieldKind.dateTime),
    FormField('ph', 'pH'),
    FormField('pao2', 'PaO₂'),
    FormField('paco2', 'PaCO₂'),
    FormField('hco3', 'HCO₃⁻'),
    FormField('be', 'BE'),
    FormField('fio2', 'FiO₂'),
  ]),
  FormGroup('落款', [
    FormField('signature', '签名'),
  ]),
];

// ============================================================
// 三、无创通气（PDF 259 / 印刷 255）
// ============================================================
const List<FormGroup> kNivMeta = [
  FormGroup('连接方式 / 呼吸机信息', [
    FormField('main_diagnosis', '主要诊断', kind: FieldKind.longText),
    FormField('mask', '连接方式', kind: FieldKind.choice,
        options: ['鼻罩', '口鼻罩']),
    FormField('mask_model', '型号'),
    FormField('vent_name', '呼吸机名称'),
    FormField('start_day', '开始第', kind: FieldKind.number, unit: '天'),
    FormField('mode', '模式'),
    FormField('params', '参数', kind: FieldKind.longText),
  ]),
];

const List<FormGroup> kNivPoint = [
  FormGroup('心电监护', [
    FormField('time', '时间', kind: FieldKind.dateTime),
    FormField('hr', 'HR', kind: FieldKind.number, unit: '次/分'),
    FormField('bp', 'BP', unit: 'mmHg'),
    FormField('spo2', 'SpO₂', kind: FieldKind.number, unit: '%'),
    FormField('mode', 'MODE'),
  ]),
  FormGroup('机械通气监测', [
    FormField('ipap', 'IPAP set/meas'),
    FormField('epap', 'EPAP set/meas'),
    FormField('rr', 'RR set/meas'),
    FormField('fio2_flow', 'FiO₂ set / Flow O₂'),
    FormField('vt', 'VT'),
    FormField('mv_leak', 'MV / MV leak'),
    FormField('ti_ttot', 'Ti/Ttot'),
  ]),
  FormGroup('报警 / 监测', [
    FormField('high_low_p', 'High/Low P'),
    FormField('high_low_rr', 'High/Low RR'),
    FormField('low_mv', 'Low MV'),
    FormField('apnea', 'Apnea'),
  ]),
  FormGroup('撤离 NPPV 时的方式', [
    FormField('humid_water', '湿化的水位'),
    FormField('heat_level', '加温档位'),
    FormField('valve_shake', '是否抖动呼吸阀'),
    FormField('aerophagia', '是否吞气打嗝'),
    FormField('sputum', '痰液颜色/黏稠度'),
    FormField('suction', '吸痰频率'),
  ]),
  FormGroup('血气分析', [
    FormField('abg_time', '时间', kind: FieldKind.dateTime),
    FormField('ph', 'pH'),
    FormField('pao2', 'PaO₂'),
    FormField('paco2', 'PaCO₂'),
    FormField('hco3', 'HCO₃⁻'),
    FormField('be', 'BE'),
    FormField('fio2', 'FiO₂'),
  ]),
  FormGroup('落款', [
    FormField('assessment', '相关操作和评估记录', kind: FieldKind.longText),
    FormField('signature', '签名'),
  ]),
];

/// 表类型常量
const String kTypeInvasive = 'invasive';
const String kTypeNiv = 'niv';

String typeTitle(String type) =>
    type == kTypeInvasive ? '有创通气' : '无创通气';

String formTitle(String type) => type == kTypeInvasive
    ? '二、呼吸治疗工作记录表（有创通气）'
    : '三、呼吸治疗工作记录表（无创通气）';

List<FormGroup> metaGroups(String type) =>
    type == kTypeInvasive ? kInvasiveMeta : kNivMeta;

List<FormGroup> pointGroups(String type) =>
    type == kTypeInvasive ? kInvasivePoint : kNivPoint;

/// 把一个字段的值转成界面/PDF 显示用的文本
String displayValue(FormField f, Map<String, dynamic> data) {
  final v = data[f.key];
  if (v == null) return '';
  if (v is List) return v.join('、');
  if (v is bool) return v ? '是' : '否';
  return v.toString();
}

/// 日期字符串 yyyy-MM-dd 工具
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final parts = s.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
